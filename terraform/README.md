# Gary lab Terraform files

Using Proxmox as a virtual server platform, these terraform files make it easy to spin up and down a known set of servers.

In my lab I have reserved IP's and hostnames in DNS for nine servers (srvr01 - srvr09).
Each directory under /lab is the terraform for each server.


Basic directory layout:

```
lab
 - shared - config files shared by all vm
 - srvr[01-09] - directory for each VM with specific settings
modules
 - oradbsrvr - terraform module with generic settings
```


## TODO:

- clean up secure information that is used by other scripts
- clean up hack for /etc/hosts tempaltes (make generic / less static)
- allow different soruce for SSH keys (not hard coded)
- look into possible race condition with cloud-init OS update and ora-lab tar install on Linux 8

Each one is based on a source module called oradbsrvr which creates the inital server image with two network interfaces and required storage for easy setup and install.

Make sure a terraform.tfvars is created in each server directory with the specific values needed for each server.

Variables:

```
v_vmid = 9999
v_name = "myserver.mydomain.com"
v_desc = "my description"
v_ip0 = "ip=0.0.0.0/24"
v_ip1 = "ip=0.0.0.0/24"
v_srcvm = "sourcevm"
v_tgtnode = "proxmox_node"
v_pool = "proxmox_pool"
v_nameserver = "0.0.0.0"
v_searchdomain = "mydomain.com"

v_sockets = 1
v_cores = 2
v_memory = 1024
```

