# frozen_string_literal: true
require 'yaml'
require 'mkmf'
require 'fileutils'
require 'socket'

# Definir las rutas base del proyecto
# DIR: Directorio raíz del proyecto
# PRIVATE_IP_FILE: Archivo donde se almacena la IP privada
# CONFIG_FILE: Archivo de configuración principal
# SAMPLE_CONFIG_FILE: Archivo de configuración de ejemplo
DIR = File.dirname(File.expand_path(__FILE__))
PRIVATE_IP_FILE = File.join(DIR, '.vagrant', 'private_ip')
CONFIG_FILE = File.join(DIR, 'config.yml')
SAMPLE_CONFIG_FILE = File.join(DIR, 'config.sample.yml')

# Crear el directorio .vagrant si no existe
FileUtils.mkdir_p(File.dirname(PRIVATE_IP_FILE))

# Verificar la existencia del archivo de configuración
# Si no existe config.yml, intentar copiar desde config.sample.yml
unless File.exist?(CONFIG_FILE)
  if File.exist?(SAMPLE_CONFIG_FILE)
    FileUtils.cp(SAMPLE_CONFIG_FILE, CONFIG_FILE)
    puts '==> predeterminado: config.yml no fue encontrado. Copiando configuraciones predeterminadas...'
  else
    puts '==> ERROR: No se encontró ni config.yml ni config.sample.yml'
    exit 1
  end
end

# Cargar la configuración del sitio desde config.yml
site_config = YAML.load_file(CONFIG_FILE)

# Gestionar la IP privada
# Leer la IP existente o generar una nueva en el rango 192.168.56.x
private_ip = if File.exist?(PRIVATE_IP_FILE)
               File.read(PRIVATE_IP_FILE).strip
             else
               nil
             end

if private_ip.nil? || !private_ip.start_with?('192.168.56.')
  private_ip = "192.168.56.#{rand(2..254)}"
  File.write(PRIVATE_IP_FILE, private_ip)
end

# Iniciar la configuración de Vagrant
Vagrant.configure("2") do |config|
  # Configuración de plugins y SSH
  config.vagrant.plugins = ['vagrant-goodhosts']  # Plugin para gestionar /etc/hosts
  config.ssh.forward_agent = true                 # Permitir reenvío de agente SSH

  # Configuración de la box base
  config.vm.box = "ubuntu/bionic64"              # Usar Ubuntu 18.04 LTS
  config.vm.hostname = site_config['name']        # Establecer nombre de host desde config

  # Configuración de dominios y aliases
  domains = get_domains(site_config)
  config.goodhosts.remove_on_suspend = true
  config.goodhosts.aliases = domains - [config.vm.hostname]

  # Configuración de red pública (solo si se usa Avahi y es macOS)
  if site_config.dig('development', 'avahi') && has_internet? && is_osx?
    config.vm.network "public_network", bridge: [
      "en0: Wi-Fi (inalámbrico)",
      "en1: Wi-Fi (inalámbrico)",
      "en0: Wi-Fi (AirPort)",
      "en1: Wi-Fi (AirPort)",
      "wlan0"
    ]
  end

  # Configuración de red privada
  config.vm.network :private_network, ip: private_ip

  # Definir nombre de la máquina virtual
  config.vm.define "#{site_config['name']}-box"

  # Configuración de carpetas compartidas
  config.vm.synced_folder DIR, '/data/wordpress/',
                         owner: 'vagrant',
                         group: 'vagrant',
                         mount_options: ['dmode=775', 'fmode=775']

  # Configuración del proveedor VirtualBox
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"                           # Asignar 4GB de RAM
    vb.cpus = "2"                                # Asignar 2 CPUs

    # Configuraciones adicionales de VirtualBox
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
  end

  # Configuración de certificados SSL
  ssl_cert_path = File.join(DIR, '.vagrant', 'ssl')
  FileUtils.mkdir_p(ssl_cert_path) unless File.exist?(ssl_cert_path)

  need_ssl = !File.exist?(File.join(ssl_cert_path, 'development.crt'))

  # Generar certificados SSL si es necesario
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

  # Agregar clave SSH pública del desarrollador a la máquina virtual
  if File.exist? File.join(Dir.home, ".ssh", "id_rsa.pub")
    id_rsa_ssh_key_pub = File.read(File.join(Dir.home, ".ssh", "id_rsa.pub"))
    config.vm.provision :shell,
                       name: "Agregar clave SSH",
                       inline: "echo '#{id_rsa_ssh_key_pub}' >> /home/vagrant/.ssh/authorized_keys && chmod 600 /home/vagrant/.ssh/authorized_keys"
  end

    # Configurar triggers de Vagrant
    vagrant_triggers(config, site_config)

    config.vm.provision "shell", path: "provision/core.sh"
end

# Funciones auxiliares

# Ejecutar comando con sudo en la máquina virtual
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

# Mostrar mensaje de notificación
def notice(text)
  puts "==> trigger: #{text}"
end

# Crear archivo vacío
def touch_file(path)
  File.open(path, "w") {}
end

# Solicitar confirmación al usuario
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

# Verificar si Vagrant está en ejecución
def vagrant_running?
  system("vagrant status --machine-readable | grep state,running --quiet")
end

# Configuración de triggers de Vagrant
def vagrant_triggers(vagrant_config, site_config)
  # Trigger después de iniciar la máquina
  vagrant_config.trigger.after :up do |trigger|
    trigger.ruby do |env, machine|
      Dir.chdir(DIR)
      sleep 3  # Esperar a que la máquina termine de iniciar

      # Ejecutar configuración inicial
      system "vagrant ssh -c development-up"

      # Verificar hooks de git
      if File.exists?(File.join(DIR, '.git', 'hooks', 'pre-commit'))
        puts "Si deseas usar el git pre-commit hook, ejecuta 'activate-git-hooks' dentro de la máquina virtual."
      end

      # Configuraciones específicas por sistema operativo
      case RbConfig::CONFIG['host_os']
      when /darwin/  # macOS
        ssl_cert_path = File.join(DIR, '.vagrant', 'ssl')
        unless File.exists?(File.join(ssl_cert_path, 'trust.lock'))
          if File.exists?(File.join(ssl_cert_path, 'development.crt')) and confirm "¿Confiar en el certificado SSL generado en el keychain de OS-X?"
            system "sudo security add-trusted-cert -d -r trustRoot -k '/Library/Keychains/System.keychain' '#{ssl_cert_path}/development.crt'"
            touch_file File.join(ssl_cert_path, 'trust.lock')
          end
        end
      when /linux/  # Linux
        # Configuraciones específicas para Linux
      end

      # Ejecutar personalizaciones adicionales
      if File.exist?(File.join(DIR, 'vagrant-up-customizer.sh'))
        notice 'Se encontró vagrant-up-customizer.sh y se está ejecutando...'
        Dir.chdir(DIR)
        system 'sh ./vagrant-up-customizer.sh'
      end
    end
  end

  # Trigger antes de detener o destruir la máquina
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

# Verificar conexión a Internet
def has_internet?
  begin
    Socket.ip_address_list.detect(&:ipv4_public?)
    true
  rescue StandardError
    false
  end
end

# Verificar si es sistema operativo macOS
def is_osx?
  RUBY_PLATFORM.include?('darwin')
end

# Obtener lista de dominios para desarrollo
def get_domains(config)
  domains = []

  # Obtener dominios de la configuración
  unless config['development'].nil?
    domains = config['development']['domains'] || []
    domains << config['development']['domain'] unless config['development']['domain'].nil?
  end

  # Agregar dominio principal .local
  domains << config['name'] + '.local'

  # Agregar subdominios predeterminados
  subdomains = %w[www webgrind adminer mailcatcher browsersync info]
  subdomains.each do |domain|
    domains << "#{domain}.#{config['name']}.local"
  end

  # Eliminar duplicados y retornar
  domains.uniq
end