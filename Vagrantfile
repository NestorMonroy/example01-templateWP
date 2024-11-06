# frozen_string_literal: true
require 'yaml'
require 'mkmf'
require 'fileutils'
require 'socket'

# Definir constantes
DIR = File.dirname(File.expand_path(__FILE__))
PRIVATE_IP_FILE = File.join(DIR, '.vagrant', 'private_ip')
CONFIG_FILE = File.join(DIR, 'config.yml')
SAMPLE_CONFIG_FILE = File.join(DIR, 'config.sample.yml')

# Configuración inicial
FileUtils.mkdir_p(File.dirname(PRIVATE_IP_FILE))

unless File.exist?(CONFIG_FILE)
  if File.exist?(SAMPLE_CONFIG_FILE)
    FileUtils.cp(SAMPLE_CONFIG_FILE, CONFIG_FILE)
    puts '==> predeterminado: config.yml no fue encontrado. Copiando configuraciones predeterminadas...'
  else
    puts '==> ERROR: No se encontró ni config.yml ni config.sample.yml'
    exit 1
  end
end

site_config = YAML.load_file(CONFIG_FILE)

private_ip = if File.exist?(PRIVATE_IP_FILE)
               File.read(PRIVATE_IP_FILE).strip
             else
               nil
             end

if private_ip.nil? || !private_ip.start_with?('192.168.56.')
  private_ip = "192.168.56.#{rand(2..254)}"
  File.write(PRIVATE_IP_FILE, private_ip)
end

# Configuración de Vagrant
Vagrant.configure("2") do |config|
  # Llamar a la configuración de triggers
  vagrant_triggers(config, site_config)

  # Resto de la configuración existente
  config.vagrant.plugins = ['vagrant-goodhosts']

  config.vm.box = "ubuntu/bionic64"
  config.ssh.forward_agent = true
  config.vm.hostname = site_config['name']

  domains = get_domains(site_config)
  config.goodhosts.remove_on_suspend = true
  config.goodhosts.aliases = domains - [config.vm.hostname]

  if site_config.dig('development', 'avahi') && has_internet? && is_osx?
    config.vm.network "public_network", bridge: [
      "en0: Wi-Fi (inalámbrico)",
      "en1: Wi-Fi (inalámbrico)",
      "en0: Wi-Fi (AirPort)",
      "en1: Wi-Fi (AirPort)",
      "wlan0"
    ]
  end

  config.vm.network :private_network, ip: private_ip

  config.vm.synced_folder DIR, '/data/wordpress/',
                         owner: 'vagrant',
                         group: 'vagrant',
                         mount_options: ['dmode=775', 'fmode=775']

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
    vb.cpus = "2"
    vb.name = "template-wp"

    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
  end

  ssl_cert_path = File.join(DIR, '.vagrant', 'ssl')
  FileUtils.mkdir_p(ssl_cert_path) unless File.exist?(ssl_cert_path)

  need_ssl = !File.exist?(File.join(ssl_cert_path, 'development.crt'))

  if need_ssl
    puts '==> SSL: Certificado no encontrado. Se generará uno nuevo...'
    config.vm.provision "shell",
                       name: "Instalar generate-ssl",
                       inline: <<-SHELL
      if [ ! -f "/usr/local/bin/generate-ssl" ]; then
        cp /vagrant/provision/scripts/generate-ssl /usr/local/bin/
        chmod +x /usr/local/bin/generate-ssl
      fi
    SHELL

    config.vm.provision "shell",
                       name: "Generar certificado SSL",
                       inline: "generate-ssl",
                       run: "always"
  end

  if File.exist? File.join(Dir.home, ".ssh", "id_rsa.pub")
    id_rsa_ssh_key_pub = File.read(File.join(Dir.home, ".ssh", "id_rsa.pub"))
    config.vm.provision :shell,
                       name: "Agregar clave SSH",
                       inline: "echo '#{id_rsa_ssh_key_pub}' >> /home/vagrant/.ssh/authorized_keys && chmod 600 /home/vagrant/.ssh/authorized_keys"
  end

  config.vm.provision "shell", path: "provision/core.sh"
end

##
# Funciones de Triggers y Helpers
##

def run_command(cmd, machine)
  exit_code = 1
  good_exit_codes = (0..255).to_a
  begin
    exit_code = machine.communicate.sudo(cmd, :elevated => true, :good_exit => good_exit_codes) do |channel, data|
      machine.ui.send(:info, data)
    end
  rescue => e
    machine.ui.send(:error, e.message)
  end
  if !good_exit_codes.include? exit_code
    exit exit_code
  end
  return exit_code
end

def notice(text)
  puts "==> trigger: #{text}"
end

def touch_file(path)
  File.open(path, "w") {}
end

def confirm(question, default=true)
  if default
    default = "yes"
  else
    default = "no"
  end

  confirm = nil
  until ["Y","N","YES","NO",""].include?(confirm)
    print "#{question} (#{default}): "
    confirm = STDIN.gets.chomp

    if (confirm.nil? or confirm.empty?)
      confirm = default
    end

    confirm.strip!
    confirm.upcase!
  end
  if confirm.empty? or confirm == "Y" or confirm == "YES"
    return true
  end
  return false
end

def vagrant_running?
  system("vagrant status --machine-readable | grep state,running --quiet")
end

##
# Configuración de Triggers
##
def vagrant_triggers(vagrant_config, site_config)
  vagrant_config.trigger.after :up do |trigger|
    trigger.ruby do |env, machine|
      # Ejecutar comandos en el directorio raíz del proyecto
      Dir.chdir(DIR)

      # Esperar a que la máquina termine de iniciar
      sleep 3

      # Ejecutar development-up
      system "vagrant ssh -c development-up"

      # Verificar git hooks
      if File.exists?(File.join(DIR, '.git', 'hooks', 'pre-commit'))
        puts "Si deseas usar el git pre-commit hook, ejecuta 'activate-git-hooks' dentro de la máquina virtual."
      end

      # Configuraciones específicas por sistema operativo
      case RbConfig::CONFIG['host_os']
      when /darwin/
        # Configuraciones específicas para macOS
        ssl_cert_path = File.join(DIR, '.vagrant', 'ssl')
        unless File.exists?(File.join(ssl_cert_path, 'trust.lock'))
          if File.exists?(File.join(ssl_cert_path, 'development.crt')) and confirm "¿Confiar en el certificado SSL generado en el keychain de OS-X?"
            system "sudo security add-trusted-cert -d -r trustRoot -k '/Library/Keychains/System.keychain' '#{ssl_cert_path}/development.crt'"
            touch_file File.join(ssl_cert_path, 'trust.lock')
          end
        end
      when /linux/
        # Configuraciones específicas para Linux
      end

      # Ejecutar personalizador si existe
      if File.exist?(File.join(DIR, 'vagrant-up-customizer.sh'))
        notice 'Se encontró vagrant-up-customizer.sh y se está ejecutando...'
        Dir.chdir(DIR)
        system 'sh ./vagrant-up-customizer.sh'
      end
    end
  end

  vagrant_config.trigger.before [:halt, :destroy] do |trigger|
    trigger.ruby do |env, machine|
      if vagrant_running?
        begin
          run_command("vagrant-dump-db", machine)
        rescue => e
          notice "No se pudo hacer el dump de la base de datos. Saltando..."
        end
      end
    end
  end
end

# Funciones auxiliares existentes
def has_internet?
  begin
    Socket.ip_address_list.detect(&:ipv4_public?)
    true
  rescue StandardError
    false
  end
end

def is_osx?
  RUBY_PLATFORM.include?('darwin')
end

def get_domains(config)
  domains = []

  unless config['development'].nil?
    domains = config['development']['domains'] || []
    domains << config['development']['domain'] unless config['development']['domain'].nil?
  end

  domains << config['name'] + '.local'

  subdomains = %w[www webgrind adminer mailcatcher browsersync info]
  subdomains.each do |domain|
    domains << "#{domain}.#{config['name']}.local"
  end

  domains.uniq
end
