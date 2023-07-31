# Hosts configuration for terraform

Each of these directories is for a custom test server.  You can configurat this anyway you like, my home lab has srvr01-srvr09 pre-defined in DNS and then I can build these out quickly based on  a few simple edits to the configuration files:

## Configuration files
### Hosts file
Edit the hosts.debian.tmpl and hosts.redhat.tmpl
1. update the line with "{{fqdn}} {{hostname}}" to have the primary IP address for that given server.
2. update the line with "{{hostname}}-priv1" to have the private IP address for that given server.  I use this network for stoarge access or for private interconnect for clusters.
3. Update the line for the NFS storage access if you have that on the private network and it will not resolve from DNS.  In the templates in GIT it says "10.10.1.x nfs-server-priv1.mydmoain.com nfs-server-priv1" change the IP address and name to match your needs

### terraform.tfvars
Edit this file to contain the variable definitions for your given host.
1. v_vmid = this is the VMID number in proxmox, this has to be unique.
2. v_name = the name fo the server as it will apper in the proxmox GUI
3. v_desc = description that will be in the proxmox GUI, I format this to be consumable by ansible.
4. v_ip0 = the IP address of the primary interface, this matches what I have in my DNS in my lab.
5. v_ip1 = the IP address for the private network (this is not in DNS)
6. v_srcvm = the name of the tempalte VM to clone the boot disk from.
7. v_tgtnode = the node of the proxmox cluster you have to start the VM on.
8. v_pool = the name of the pool in proxmox to create the VM in.
9. v_nameserver = the IP address of the DNS server in your lab (sets in the server resolve.conf).
10. v_searchdomain = the search domain for your lab (sets in the server resolve.conf).
11. v_sockets = number of virtual CPU sockets
12. v_cores = number of virtual CPU cores
13. v_memory = amount of virtual memory in MB


### Shared secrets
at this time the code is very rudemintary for shared secrets.  These are stored in a configuration file under the /lab/shared folder.  They are used for all server builds and used by the ora-lab scripts.  The goal is to move these to a secret tool / store and pull them from their instead of this clear text file.  Be sure you create secure.conf file from the secure_template.conf.


### server.conf
This configuration file is completly dependent on using the other lab build scripts.
See more information about it in the lab scripts README.  It should be created from the server_template.conf file and named server.conf

## building your vm
you sould have the following files in your servers build directory before issuing terraform commands:
- hosts.debian.tmpl
- hosts.redhat.tmpl
- main.tf
- server.conf
- terraform.tfvars
- variables.tf

Outside of this you should have the central build modules in your terraform paths.  It should look like this:
```
|- terraform
   |- lab
      |- shared
      |- srvr01 (or whatever your server names are)
      |- srvr02 (or whatever your server names are)
      |- srvr... (or whatever your server names are)
   |- modules
      |- oradbsrvr
```

