#!/bin/bash

# Settings for the script
newvm_id=####     # VM ID number of template
temp_name=vmtempname  # name of VM tempalte
pve_repo_root=local-slow01   # disk repo for boot drive
pve_repo_u01=local-fast01    # disk repo for second u01 mount
source_qcow=OL7U9_x86_64-olvm-b77.qcow2

# Check if we have command line parameters
if [ "$#" -gt 0 ]; then
  newvm_id=$1
  temp_name=$2
  source_qcow=$3
fi

# following items are for bringing a NFS mount online 
use_nfs=TRUE
nfs_mount=mynfsserver.com:/mnt/Pool1/Software
mount_path=/mnt/software

# Source CloudInit image
#  Note the file should be named qcow2 unless it is a qcow verion 1 file
#  if the name is not correct the tooling will fail with the error:
#  qemu-img: Could not open 'OL9U0_x86_64-kvm-b142.qcow': qcow (v1) does not support qcow version 3
# source_img=/mnt/software/Linux/CentOS-7-x86_64-GenericCloud-20150628_01.qcow2
source_img=${mount_path}/Oracle/OEL/${source_qcow}

echo "Creating new VM template with following settings:"
echo "  Source disk:   $source_img"
echo "  VM ID:         $newvm_id"
echo "  Template Name: $temp_name"

# Temporary mount software mount
# this is where the source image is located
if [ "$use_nfs" == "TRUE" ]; then
    [ ! -d "${mount_path}" ] && mkdir "${mount_path}"
    if mount -t nfs "${nfs_mount}" "${mount_path}"; then
        echo "INFO: Success mounting NFS: $mount_path"
    else
        echo "ERROR: Failed mounting NFS: $mount_path"
        exit 1
    fi
fi;

# check source disk image
if [ ! -f "$source_img" ]; then
    echo "ERROR: Could not read source disk image: $source_img"
    exit 1
else
    if [ "${source_qcow##*.}" == "qcow" ]; then
        echo "ERROR: Disk image file should be named qcow2 or qcow3: $source_img"
        exit 1
    fi
fi

# Create a template VM
qm create ${newvm_id} --cpu cputype="host" --memory 2048 --net0 virtio,bridge=vmbr0 --name "${temp_name}" --pool "Templates"
return_code=$?


if (( $return_code < 1 )); then
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
else
    echo "ERROR: Create VM $newvm_id failed return code: $return_code"
fi

# Unmount the NFS mount used to pull the image.
if [ "$use_nfs" == "TRUE" ]; then
  umount "${mount_path}"
fi;

#END
