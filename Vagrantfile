# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.define "master" do |master|
    master.vm.box = "centos/7"
    master.vm.provider "hyperv" do |hv|
      hv.vmname = "K8s-master"
      hv.memory = 1024
      hv.maxmemory = 2048
      hv.cpus = 2
      hv.differencing_disk = true
    end
    master.vm.synced_folder ".", "/vagrant", type: "rsync",
      rsync__exclude: ".git/"

    master.vm.hostname = "master.localdomain"
    master.vm.provision "shell", path: "disable-swap.sh"
    master.vm.provision "shell", path: "install-docker.sh"
    master.vm.provision "shell", path: "install-k8s.sh"
    master.vm.provision "shell", inline: "kubeadm init"
  end


  config.vm.define "nodea" do |nodea|
    nodea.vm.box = "centos/7"
    nodea.vm.provider "hyperv" do |hv|
      hv.vmname = "K8s-nodea"
      hv.memory = 1024
      hv.maxmemory = 2048
      hv.cpus = 2
      hv.differencing_disk = true
    end
    nodea.vm.synced_folder ".", "/vagrant", type: "rsync",
      rsync__exclude: ".git/"

    nodea.vm.hostname = "nodea.localdomain"

    nodea.vm.provision "shell", path: "disable-swap.sh"
    nodea.vm.provision "shell", path: "install-docker.sh"
    nodea.vm.provision "shell", path: "install-k8s.sh"
  end

end