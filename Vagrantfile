Vagrant.configure("2") do |config|
    config.vm.box = "centos/7"
    config.vm.boot_timeout = 300
    config.vm.provision "shell", path: "vagrant-provision.sh", run: "once"
    config.vm.provision "shell", path: "vagrant-provision-disks.sh", run: "always"
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.box_check_update = true

    config.vm.provider :virtualbox do |vb|
        vb.gui = false
        vb.name = "#{ENV['VM_NAME']}"
        vb.memory = "#{ENV['VM_MEMORY']}"
        vb.cpus = "#{ENV['VM_CPUS']}"
    end
end

