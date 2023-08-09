# ora-lab - Scripts for creating VM servers in Proxmox

Scripts and setups to use Terraform with Proxmox to build out Oracle servers.

## Setup:
- Create user in Proxmox with proper rights (make sure it has rights to proper pools and storage)
- Setup template machines to build from
- Have resources ready (IP, storage etc..)
- configure terraform

## Repository Structure

```
/scripts      -- shell scripts used through builds
/terraform    -- terraform scripts or templates
/test         -- BATS testing files for scripts - you don't need these to use the scripts
```

---------------------------------------------
# Instructions
## Part I - one time setup for API access by Terraform
1. Create a group to provide permissions to
   Datacenter -> Users -> Add
2. Create a API user in Proxmox.
   Datacenter -> Users -> Add
   Be sure to add the user to the group created in step 1
3. Give access rights to the group created in step
   Datacenter -> Permissions -> Add
   Example rights would be "PVEVMAdmin" "PVEPoolAdmin" roles in order to create VM's and add storage to VM's

## Part II - create a VM tempalte to build you VM's from
The basis of this process is to have a VM template that will be used to thin clone to a new VM.
The easiest way to build this tempalte is from a pre-built cloud-init image. Most Linux distributions provide these images.  We are using QCOW2 image files.
Download the image and stage it somewhere accessble by the proxmox server.
This script can use NFS mount for the staging.


1. Copy the pve-mk-template.sh to your proxmox server
2. Update the paramters at the top of the script:
    1. newvm_id = # The ID number of the template VM to create, this needs to be unique
    2. temp_name = # the name of the template
    3. pve_repo_root = # pve storage repo for the root volume
    4. pve_repo_u01 = # pve storage repo for the second disk (/u01)
    5. source_img = # full path and file name of the source image file
    6. use_nfs = # set to FALSE to not use NFS mount to source the tempalte image
    7. nfs_mount = # Full NFS path to the mount and server NFS is shared from
    8. mount_path = # location to temporaryly mount the NFS on the proxmox server
3. Run the script as the root user on the proxmox server
```bash
./pve-mk-template.sh
```
## Part III configure / stage Terraform files

Files that need to be configured / created
- terraform/shared/secure.conf
- scripts/defaut.conf
- terraform/lab/srvr[01-09]/terraform.tfvars
- terraform/lab/srvr[01-09]/server.conf

## Part IV - create a VM with Terraform
1. Download the scripts from GIT
2. create directory under /terraform for you new VM: E.G.
```bash
mkdir terraform/server01
```
3. Copy the tereform template files E.G:
```bash
cp terraform/srvr01/* terraform/srvr02
cp scripts/server_template.conf terraform/srvr02/server.conf
```
4. Copy the terraform_template.tfvars to terraform.tfvars and edit it updateing:
    1. name = # this is your new VM server FQDN name
    2. desc = # this is the description that will show up in the Proxmox GUI
    3. vmid = # this is the ID number of the VM in Proxmox, this needs to be unique
    4. target_node = # this is your proxmox server name, if you have more than one server, this is the server the VM will be created on
    5. clone = # this is the name of the source VM tempalte that will be cloned
    6. ipconfig0 = # this is the IP address, netmask, and default gateway of the first ethernet interface
    7. Put your SSH public key on a line between the << EOF and line by it self with EOF.  This is the only way to login to your VM once created.
5. Edit the the modules/oradbsrvr/provider.tf file to provide your Proxmox API URL and username:
    1. pm_api_url = # the URL to your proxmox server api, like https://host.com:8006/api2/json
    2. pm_user = # the username for API acces, should be in the form user@realm or apiuser@pve
6. Initialize terraform, this will verify you have the provider downloaded
```bash
terraform init
```
7. You can check what will be built by reviewing the terrafrom plan
```bash
terraform plan
```
8. Build out your VM with terraform
```bash
terraform apply
```
9. after the VM is built you can login with the default cloud user and the key file you provided
```bash
ssh cloud-user@mynewserver.com
```
Note: if you have a private / public key pair that you are using that is different than your default user you can also point to the key file with the following command on Linux / MAC.  If you are using Windows, then be sure you have Putty Agent setup or an equivilent SSH key agent.
```bash
ssh -i /home/user/ssh/my_private_key cloud-user@mynewserver.com
```

## Part IV - Oracle build out
Oracle build will happen automatically based on the contents of your server.conf file.
Use the server_template.conf as a starting point, setting the verions of the datbase and options you would like to configure like sample schema, ORDS, or RWL load simulator.

# Some useful links:

## Cloud Image - customizing existings ones
https://whattheserver.com/proxmox-cloud-init-os-template-creation/

Grab the cloud image base link for desired OS: Openstack has a nice page on this: https://docs.openstack.org/image-guide/obtain-images.html

Creating cloud image from scratch
- create VM
- make sure cloudinit device is created

These are some direct links:
https://cloud.centos.org/centos/7/images/
https://cloud-images.ubuntu.com/
http://yum.oracle.com/oracle-linux-templates.html

## proxmox command line examples
https://gist.github.com/dragolabs/f391bdda050480871ddd129aa6080ac2

## Terraform command line examples:
https://dzone.com/articles/terraform-cli-cheat-sheet

## Proxmox Cloud Init information
https://pve.proxmox.com/wiki/Cloud-Init_FAQ#Creating_a_custom_cloud_image

## Terraform Proxmox provider
https://github.com/Telmate/terraform-provider-proxmox

## Frits hoogland - Vagrant-builder for Oracle
https://gitlab.com/FritsHoogland/vagrant-builder


# Tips
- looking for ZFS storage files, use "zfs list" on PVE server.
-

---------------------------------------------

# Testing scripts

To test the scripts you will need the BATS testing framework.

```
wget https://github.com/bats-core/bats-core/archive/refs/heads/master.zip
unzip zip file
alias bats=~/bats-core-master/bin/bats

wget https://github.com/ggordham/ora-lab/archive/refs/heads/main.zip
unzip zip file
cd ora-lab-master/scripts

export mosUser=username
export mosPass=password
bats ../test/getMosPatch.bats
```


