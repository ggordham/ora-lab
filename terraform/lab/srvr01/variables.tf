# Variables for SRVR01 for gary lab

# VM sepcific information
variable "v_vmid" {
  type = number
}

variable "v_name" {
  type = string
}

variable "v_desc" {
  type = string
}

variable "v_ip0" {
  type = string
}

variable "v_ip1" {
  type = string
}

variable "v_cores" {
  type = number
}

variable "v_sockets" {
  type = number
}

variable "v_memory" {
  type = number
}

# VM Clone source information
variable "v_srcvm" {
  type = string
}

# Proxmox node infomraiton
variable "v_tgtnode" {
  type = string
}

variable "v_pool" {
  type = string
}

# general network information
variable "v_nameserver" {
  type = string
}

variable "v_searchdomain" {
  type = string
}
