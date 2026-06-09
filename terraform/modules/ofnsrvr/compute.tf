
resource "proxmox_vm_qemu" "proxmox_vm" {
  #### Customzie these settings for each VM
  name  = var.v_name
  vmid = var.v_vmid
  #  Custom cloud config file for this VM
  ipconfig0 = var.v_ip0
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

  # Ignore changes to the network
  ## MAC address is generated on every apply, causing
  ## TF to think this needs to be rebuilt on every apply
  lifecycle {
    ignore_changes = [
      network,
    ]
  }


  # this section will set the cloud-init hosts file template, load get-ofn.sh script and setup storage
  provisioner "remote-exec" {
    inline = [
      "/usr/bin/sudo su -c \"/bin/sed -i 's/127.0.1.1 {{fqdn}} {{hostname}}//g' /etc/cloud/templates/hosts.redhat.tmpl\"",
      "/usr/bin/sudo su -c \"echo $( /bin/hostname -I ) {{fqdn}} {{hostname}} >> /etc/cloud/templates/hosts.redhat.tmpl\"",
      "/usr/bin/curl https://raw.githubusercontent.com/ggordham/ofn/main/getofn.sh > /tmp/getofn.sh",
      " if (( $? < 1 )); then echo \"Download getofn.sh success\"; else echo \"ERROR downloading getofn.sh!\"; fi",
      "/bin/chmod +x /tmp/getofn.sh",
      "echo Running getofn.sh",
      "/bin/bash /tmp/getofn.sh > /tmp/tera-getofn.log --reboot 2>&1",
      " if (( $? < 1 )); then echo \"getofn.sh run success\"; else echo \"ERROR running getofn.sh!\"; fi",
      "echo Running ofn_tera_storage.sh",
      "sudo /opt/ofn/tests/ofn_tera_storage.sh > /tmp/ofn-tera-storage.log 2>&1",
      " if (( $? < 1 )); then echo \"ofn_tera_storage.sh run success\"; else echo \"ERROR running ofn_tera_storage.sh!\"; fi"
    ]
    connection {
      type = "ssh"
      host = self.default_ipv4_address
      user = "cloud-user"
      private_key = file(pathexpand("~/.ssh/id_rsa"))
    }
  }


  # tried to remove local SSH key but var.v_name can't
  # be referenced in destroy section only self. variables
  #provisioner "local-exec" {
  #  when    = "destroy"
  #  command = "/usr/bin/ssh-keygen -R ${var.v_name}"
  #}
}


