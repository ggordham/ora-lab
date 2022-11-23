#!/bin/bash

# vm-bld-ora.sh

# based on Vagrant Builder steps from Frits Hoogland

# Settings
BASE_DIR=/home/cloud-user
mos_username=gary.gordhamer@viscosityna.com
mos_password=Y4aMHu17JKcG0vAp

# Server Information
linux="FritsHoogland/oracle-7.9"
selinux="N"
filesystem="xfs"
hostonly_network_ip_address=""

# software version settings
asm_version="''"
database_version="19.9.0.0.0"
stage_directory="/u01/install"

# Database Settings
database_name=""
global_password="Oracle_4U"
asm_diskdiscoverystring_without_asterisk="/dev/oracle_asm_udev/"
database_characterset="UTF8"
redologfile_size="100"
pluggable_database="N"
sga_target_mb=1000
pga_aggregate_target_mb=500


# Install required RPM's
sudo yum -y install oracle-epel-release-el7
sudo yum -y install git ansible wget
sudo yum -y rng-tools

# Enable RNGD
sudo systemctl enable rngd
sudo systemctl start rngd

# Configure firewalld for Oracle Listener
firewall-cmd --permanent --zone=public --add-port=1521/tcp
firewall-cmd --reload

# clone oracle-database-setup
mkdir "${BASE_DIR}/oracle-database-setup"
git clone https://gitlab.com/FritsHoogland/oracle-database-setup.git "${BASE_DIR}/oracle-database-setup"

# if the copied files happened to be readable only to the owner, change them to world readable
find "${BASE_DIR}/oracle-databse-setup" -type f -exec chmod o+r \{\} \; 

# the playbook to setup oracle is run using a settings file in the VM, which reflects the settings made above.
echo "create settings file"
cat << SETTINGS_FILE > "${BASE_DIR}/oracle-database-setup/vars/settings.yml"
---
mosuser: ${mos_username}
host_set_ip_address: ${hostonly_network_ip_address}
oracle_base: /u01/app/oracle
database_name: ${database_name}
global_password: ${global_password}
pga_aggregate_target_mb: ${pga_aggregate_target_mb}
sga_target_mb: ${sga_target_mb}
asm_create_file_dest: DATA
asm_device: sdc
db_create_file_dest: /u01/app/oracle/oradata
asm_diskdiscoverystring_without_asterisk: ${asm_diskdiscoverystring_without_asterisk}
linux: ${linux}
asm_version: ${asm_version}
database_version: ${database_version}
stage_directory: ${stage_directory}
filesystem: ${filesystem}
database_characterset: ${database_characterset}
redologfile_size: ${redologfile_size}
pluggable_database: ${pluggable_database}
selinux: ${selinux}
SETTINGS_FILE

# Setup software mount
echo "freenas-priv1:/mnt/Pool1/Software /mnt/software nfs ro,_netdev 0 0" | sudo tee -a /etc/fstab
sudo mkdir /mnt/software
sudo ln -s /mnt/software/Oracle/database/19c /vagrant
sudo mount /mnt/software

# in order to make the MOS password not easily readable, use ansible vault to store it encrypted
echo "create encrypted vars/mospass.yml file (installs ansible)"
cd "${BASE_DIR}/oracle-database-setup" || exit
#    ansible.extra_vars = { password: "#{mos_password}" }
#    ansible.playbook = "encrypt_mospass.yml"
ansible-playbook --connection=local --inventory 127.0.0.1, --limit 127.0.0.1 -e password=${mos_password} encrypt_mospass.yml


# run the setup playbook to install oracle
source ~/.bashrc

echo "install oracle software"
cd "${BASE_DIR}/oracle-database-setup" || exit
#    ansible.playbook = "setup.yml"
ansible-playbook --connection=local --inventory 127.0.0.1, --limit 127.0.0.1 setup.yml



