# Variables for SRVR01 for gary lab

# VM sepcific information
variable "v_vmid" {
  type = number
  default = 9999
}

variable "v_name" {
  type = string
  default = "NONAME"
}

variable "v_desc" {
  type = string
  default = "NO DESCRIPTION GIVEN"
}

variable "v_ip0" {
  type = string
  default = "172.0.0.1/24"
}

variable "v_ip1" {
  type = string
  default = "172.0.0.2/24"
}

variable "v_cores" {
  type = number
  default = 1
}

variable "v_sockets" {
  type = number
  default = 1
}

variable "v_memory" {
  type = number
  default = 1024
}

# VM Clone source information
variable "v_srcvm" {
  type = string
  default = "NOSRC"
}

# Proxmox node infomraiton
variable "v_tgtnode" {
  type = string
  default = "NOTARGET"
}

variable "v_pool" {
  type = string
  default = "NOPOOL"
}

# general network information
variable "v_nameserver" {
  type = string
  default = "172.0.0.1"
}

variable "v_searchdomain" {
  type = string
  default = ""
}
