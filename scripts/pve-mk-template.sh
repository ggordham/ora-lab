#!/bin/bash

# Settings for the script
newvm_id=9028     # VM ID number of template
temp_name=vm9028temp  # name of VM tempalte
pve_repo_root=local-slow01   # disk repo for boot drive
pve_repo_u01=local-fast01    # disk repo for second u01 mount

# Source CloudInit image
# source_img=/mnt/software/Linux/CentOS-7-x86_64-GenericCloud-20150628_01.qcow2
source_img=/mnt/software/Oracle/OEL/OL7U9_x86_64-olvm-b77.qcow2

# following items are for bringing a NFS mount online 
nfs_mount=freenas-priv1:/mnt/Pool1/Software
mount_path=/mnt/software


# Temporary mount software mount
# this is where the source image is located
mkdir /mnt/software
mount -t nfs ${nfs_mount} ${mount_path}

# Create a template VM
qm create ${newvm_id} --cpu cputype="host" --memory 2048 --net0 virtio,bridge=vmbr0 --name "${temp_name}" --pool "Templates"

# Import the image file
qm importdisk ${newvm_id} ${source_img} ${pve_repo_root} --format qcow2

# Set the required paramters for couldinit
qm set ${newvm_id} --scsihw virtio-scsi-pci --scsi0 ${pve_repo_root}:vm-${newvm_id}-disk-0
qm set ${newvm_id} --ide2 ${pve_repo_root}:cloudinit
qm set ${newvm_id} --boot c --bootdisk scsi0
qm set ${newvm_id} --serial0 socket --vga serial0

# add a second disk of 50GB (this will be /u01)
pvesm alloc ${pve_repo_u01} ${newvm_id} vm-${newvm_id}-disk-1 50G
qm set ${newvm_id} --scsihw virtio-scsi-pci --scsi1 ${pve_repo_u01}:vm-${newvm_id}-disk-1

# shcnage the VM int a template
qm template ${newvm_id}

# Unmount the NFS mount used to pull the image.
umount /mnt/software

#END
