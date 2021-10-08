
# Require the proxmox plugin
terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = ">=1.0.0"
    }
  }
}

# This section covers the build out of a VM

resource "proxmox_vm_qemu" "proxmox_vm" {
  name  = "VM_FQDN.COM"
  desc = "DESCRIPTION FOR NEW VM"
  vmid = ###
  target_node = "PVE_NODE"
  pool = "PVE_POOL_NAME"
  clone = "SRC_TEMPLATE_NAME"
  full_clone = false
  clone_wait = 15
  agent = 1

  os_type = "cloud-init"
  cores = 2
  sockets = 1
  vcpus = 0
  cpu = "host"
  memory = 8192
  numa = false
  scsihw = "virtio-scsi-pci"
  bootdisk = "scsi0"
  boot = "cdn"
  onboot = false

#  disk {
#    size = "32G"
#    type = "scsi"
#    storage = "local-slow01"
#  }

  network {
    model = "virtio"
    bridge = "vmbr0"    
    # tag = 256 # don't need a tag
  }

  # Ignore changes to the network
  ## MAC address is generated on every apply, causing
  ## TF to think this needs to be rebuilt on every apply
  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  # cloud init settings
  ipconfig0 = "ip=192.168.0.XX/24,gw=192.168.0.1"
  sshkeys = <<EOF
PUT YOUR SSH KEY HERE
EOF

}


