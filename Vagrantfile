require 'yaml'
require 'mkmf'
require 'fileutils'
require 'socket'

# Create config file
config_file = File.join(DIR, 'config.yml')

unless File.exists?(config_file)
  # Usa el archivo de muestra en su lugar
  FileUtils.copy config_file
  puts '==> predeterminado: config.yml no fue encontrado. Copiando configuraciones predeterminadas desde los archivos de muestra...'
end

site_config = YAML.load_file(config_file)

private_ip = nil
if File.exists?(private_ip_file)
  private_ip = File.open(private_ip_file, 'rb') { |file| file.read }
end

if private_ip.nil? || !private_ip.start_with?('192.168.56.')
  private_ip = "192.168.56.#{rand(2..254)}"
  File.write(private_ip_file, private_ip)
end

Vagrant.configure("2") do |config|
  config.vagrant.plugins = ['vagrant-goodhosts']

  config.vm.box = "ubuntu/bionic64"

  # Usa la clave SSH de la máquina host para que podamos ingresar a producción
  config.ssh.forward_agent = true

  # Usa el nombre de la caja como el nombre del host
  config.vm.hostname = site_config['name']

  # Solo usa avahi si la configuración tiene esto
  # desarrollo:
  #   avahi: true
  if site_config['development']['avahi'] && has_internet? && is_osx?
    # La caja utiliza avahi-daemon para hacerse disponible en la red local
    config.vm.network "public_network", bridge: [
      "en0: Wi-Fi (inalámbrico)",
      "en1: Wi-Fi (inalámbrico)",
      "en0: Wi-Fi (AirPort)",
      "en1: Wi-Fi (AirPort)",
      "wlan0"
    ]
  end

  # Usa una dirección IP aleatoria
  # Esto es necesario para actualizar el archivo /etc/hosts
  config.vm.network :private_network, ip: private_ip


  config.vm.synced_folder ".", "/vagrant"

  config.vm.provider "virtualbox" do |vb|
  # Display the VirtualBox GUI when booting the machine
  #  vb.gui = true
  #
  # Customize the amount of memory on the VM:
    vb.memory = "4096"  # 4096MB o 4 GB
    vb.cpus = "2"
    vb.name = "template-wp"
  end
  # Enable provisioning with a shell script. Additional provisioners such as
  # Ansible, Chef, Docker, Puppet and Salt are also available. Please see the
  # documentation for more information about their specific syntax and use.
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Enable provisioning with a shell script. Additional provisioners such as
  # Ansible, Chef, Docker, Puppet and Salt are also available. Please see the
  # documentation for more information about their specific syntax and use.
  config.vm.provision "shell", path: "provision/core.sh"
end