# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  config.vm.box = "dominicjprice/corepure64-7.2"

  config.vm.network "private_network", type: "dhcp"

  config.vm.provider "virtualbox" do |v|
    v.memory = 4096
    v.cpus = 2
  end

  config.vm.provision "shell", run: "always", inline: "udhcpc"

  config.vm.provision "shell", privileged: false, inline: <<-SHELL

    install_tcz() {
      sudo cp /vagrant/tinycore/$1 /etc/sysconfig/tcedir/optional
      tce-load -i $1
      if [ -z "`cat /etc/sysconfig/tcedir/onboot.lst | grep $1`" ]; then
        sudo sh -c "echo $1 >> /etc/sysconfig/tcedir/onboot.lst"
      fi
    }
    install_tcz iptables.tcz
    install_tcz docker.tcz

  SHELL

  config.vm.provision "shell", inline: <<-SHELL

    if [ ! -e "/etc/ssl/certs/ca-certificates.crt" ]; then
      mkdir -p /etc/ssl/certs
      cp /vagrant/tinycore/ca-certificates.crt /etc/ssl/certs
    fi

    if [ -z "`cat /opt/.filetool.lst | grep /etc/fstab`" ]; then
      cp -pr /var /mnt/sda1
      mount --bind /mnt/sda1/var /var
      echo -e "/mnt/sda1/var\t/var\tnone\tbind\t0\t0" >> /etc/fstab
      echo "/etc/fstab" >> /opt/.filetool.lst
      /usr/bin/filetool.sh -b
    fi

    if [ -z "`cat /opt/.filetool.lst | grep ca-certificates.crt`" ]; then
      echo "/etc/ssl/certs/ca-certificates.crt" >> /opt/.filetool.lst
      /usr/bin/filetool.sh -b
    fi

    if [ -z "`cat /opt/bootlocal.sh | grep cgroupfs-mount`" ]; then
      echo "/etc/init.d/cgroupfs-mount &> /dev/null &" >> /opt/bootlocal.sh
      /etc/init.d/cgroupfs-mount &> /dev/null
    fi

    if ! getent group docker > /dev/null; then
      addgroup -S docker
      addgroup vagrant docker
      /usr/bin/filetool.sh -b
    fi

    if [ -z "`cat /opt/bootlocal.sh | grep dockerd`" ]; then
      export PATH=/usr/local/sbin:$PATH
      export DOCKER_RAMDISK=true
      nohup /usr/local/bin/dockerd -s overlay2 &> /dev/null &
      echo "export DOCKER_RAMDISK=true" >> /opt/bootlocal.sh
      echo "mount -a" >> /opt/bootlocal.sh
      echo "/usr/local/bin/dockerd -s overlay2 &> /dev/null &" >> \
          /opt/bootlocal.sh
    fi
    
    exit 0

  SHELL

end
