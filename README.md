# ora-lab - Scripts for creating VM servers in Proxmox

Scripts and setups to use Terraform with Proxmox to build out Oracle servers.

## Setup:
- Create user in Proxmox with proper rights (make sure it has rights to proper pools and storage)
- Setup template machines to build from
- Have resources ready (IP, storage etc..)
- configure terraform

## Repository Structure
```/scripts      -- shell scripts used through builds```
```/terraform    -- terraform scripts or templates```

## Instructions
### Part I - one time setup for API access by Terraform
1. Create a group to provide permissions to
   Datacenter -> Users -> Add
2. Create a API user in Proxmox.
   Datacenter -> Users -> Add
   Be sure to add the user to the group created in step 1
3. Give access rights to the group created in step
   Datacenter -> Permissions -> Add
   Example rights would be "PVEVMAdmin" "PVEPoolAdmin" roles in order to create VM's and add storage to VM's

### Part II - create a VM tempalte to build you VM's from


### Part III - create a VM with Terraform
1. Download the scripts from GIT
2. create directory under /terraform for you new VM: E.G.
```bash
mkdir terraform/server01
```
3. Copy the tereform template files: E.G.
```bash
cp terraform/ora-srvr/*.tf terraform/server01
```
4. Edit the main.tf file under terraform/server01 update:
    1. name = # this is your new VM server FQDN name
    2. desc = # this is the description that will show up in the Proxmox GUI
    3. vmid = # this is the ID number of the VM in Proxmox, this needs to be unique
    4. target_node = # this is your proxmox server name, if you have more than one server, this is the server the VM will be created on
    5. clone = # this is the name of the source VM tempalte that will be cloned
    6. ipconfig0 = # this is the IP address, netmask, and default gateway of the first ethernet interface
    7. Put your SSH public key on a line between the << EOF and line by it self with EOF.  This is the only way to login to your VM once created.
5. Edit the the provider.tf file to provide your Proxmox API URL and username:
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


### Part IV - Coming soon, build out Oracle DB

## Some useful links:

### Cloud Image - customizing existings ones
https://whattheserver.com/proxmox-cloud-init-os-template-creation/

Grab the cloud image base link for desired OS: Openstack has a nice page on this: https://docs.openstack.org/image-guide/obtain-images.html

Creating cloud image from scratch
- create VM
- make sure cloudinit device is created

These are some direct links:
https://cloud.centos.org/centos/7/images/
https://cloud-images.ubuntu.com/
http://yum.oracle.com/oracle-linux-templates.html

### proxmox command line examples
https://gist.github.com/dragolabs/f391bdda050480871ddd129aa6080ac2

### Terraform command line examples:
https://dzone.com/articles/terraform-cli-cheat-sheet

### Proxmox Cloud Init information
https://pve.proxmox.com/wiki/Cloud-Init_FAQ#Creating_a_custom_cloud_image

### Terraform Proxmox provider
https://github.com/Telmate/terraform-provider-proxmox

### Frits hoogland - Vagrant-builder for Oracle
https://gitlab.com/FritsHoogland/vagrant-builder


## Tips
- looking for ZFS storage files, use "zfs list" on PVE server.
-
