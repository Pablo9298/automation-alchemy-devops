# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # Base box
  config.vm.box = "ubuntu/jammy64"
  config.vm.box_check_update = false

  # Disable default synced folder
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Common provisioning for all VMs
  config.vm.provision "shell", inline: <<-SHELL
    # Update system
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get upgrade -y
    
    # Install Python for Ansible
    apt-get install -y python3 python3-pip
  SHELL

  # VM definitions
  machines = {
    "lb" => {
      hostname: "loadbalancer",
      ip: "192.168.56.10",
      memory: 512,
      cpus: 1
    },
    "web1" => {
      hostname: "webserver1",
      ip: "192.168.56.11",
      memory: 1024,
      cpus: 1
    },
    "web2" => {
      hostname: "webserver2",
      ip: "192.168.56.12",
      memory: 1024,
      cpus: 1
    },
    "app" => {
      hostname: "appserver",
      ip: "192.168.56.13",
      memory: 1024,
      cpus: 1
    },
    "jenkins" => {
      hostname: "jenkinsserver",
      ip: "192.168.56.14",
      memory: 2048,
      cpus: 2
    }
  }

  # Create VMs
  machines.each do |name, machine_config|
    config.vm.define name do |machine|
      # Set hostname
      machine.vm.hostname = machine_config[:hostname]
      
      # Network configuration
      machine.vm.network "private_network", 
        ip: machine_config[:ip],
        netmask: "255.255.255.0"
      
      # VirtualBox configuration
      machine.vm.provider "virtualbox" do |vb|
        vb.name = machine_config[:hostname]
        vb.memory = machine_config[:memory]
        vb.cpus = machine_config[:cpus]
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
      end
    end
  end

  # Run Ansible provisioning only after all VMs are up
  config.vm.provision "ansible", run: "never" do |ansible|
    ansible.playbook = "ansible/playbook.yml"
    ansible.inventory_path = "ansible/inventory.ini"
    ansible.limit = "all"
    ansible.compatibility_mode = "2.0"
  end
end
