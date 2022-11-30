
resource "proxmox_vm_qemu" "proxmox_vm" {
  #### Customzie these settings for each VM
  name  = var.v_name
  vmid = var.v_vmid
  #  Custom cloud config file for this VM
  ipconfig0 = var.v_ip0
  ipconfig1 = var.v_ip1
  #### End of custom settings for this VM
  sshkeys = file(pathexpand("~/.ssh/id_rsa.pub"))
  desc = var.v_desc
  target_node = var.v_tgtnode
  pool = var.v_pool
  clone = var.v_srcvm
  full_clone = false
  # clone_wait = 15
  agent = 1

  nameserver = var.v_nameserver
  searchdomain = var.v_searchdomain

  os_type = "cloud-init"
  cores = var.v_cores
  sockets = var.v_sockets
  vcpus = 0
  cpu = "host"
  memory = var.v_memory
  numa = false
  scsihw = "virtio-scsi-pci"
  bootdisk = "scsi0"
  boot = "cdn"
  onboot = false

  # the first item will be eth0, the second eth1
  network {
    model = "virtio"
    bridge = "vmbr0"    
  }
  network {
    model = "virtio"
    bridge = "vmbr2"    
  }


  # Ignore changes to the network
  ## MAC address is generated on every apply, causing
  ## TF to think this needs to be rebuilt on every apply
  lifecycle {
    ignore_changes = [
      network,
    ]
  }


  # this section will copy the updated hosts file tempalte to the server
  provisioner "file" {
    source = "hosts.redhat.tmpl"
    destination = "/tmp/hosts.redhat.tmpl"
    connection {
      type = "ssh"
      host = self.default_ipv4_address
      user = "cloud-user"
      private_key = file(pathexpand("~/.ssh/id_rsa"))
    }
  }
  provisioner "file" {
    source = "hosts.debian.tmpl"
    destination = "/tmp/hosts.debian.tmpl"
    connection {
      type = "ssh"
      host = self.default_ipv4_address
      user = "cloud-user"
      private_key = file(pathexpand("~/.ssh/id_rsa"))
    }
  }
     
  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/hosts.redhat.tmpl /etc/cloud/templates/hosts.redhat.tmpl",
      "sudo mv /tmp/hosts.debian.tmpl /etc/cloud/templates/hosts.debian.tmpl",
      "sudo chown root:root /etc/cloud/templates/hosts.redhat.tmpl",
      "sudo chown root:root /etc/cloud/templates/hosts.debian.tmpl",
      "sudo mkdir /opt/ora-lab",
      "sudo chown cloud-user:cloud-user /opt/ora-lab",
      "/usr/bin/curl https://raw.githubusercontent.com/ggordham/ora-lab/main/scripts/get-ora-lab.sh > /tmp/get-ora-lab.sh",
      "/bin/bash /tmp/get-ora-lab.sh"
    ]
    connection {
      type = "ssh"
      host = self.default_ipv4_address
      user = "cloud-user"
      private_key = file(pathexpand("~/.ssh/id_rsa"))
    }
  }

  provisioner "file" {
    source = "server.conf"
    destination = "/opt/ora-lab/scripts/server.conf"
    connection {
      type = "ssh"
      host = self.default_ipv4_address
      user = "cloud-user"
      private_key = file(pathexpand("~/.ssh/id_rsa"))
    }
  }
 


}


