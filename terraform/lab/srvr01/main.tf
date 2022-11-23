# main script for srvr01 for gary lab
# calls moduels for most of the configuration
#
# verify variables.tf is setup correctly with correct values
#  Note we are seting module variables to the value of local 
#   variables

module "module_oradbsrvr" {
  source = "./../../modules/oradbsrvr"

  v_vmid = var.v_vmid
  v_name = var.v_name
  v_desc = var.v_desc
  v_ip0 = var.v_ip0
  v_ip1 = var.v_ip1
  v_srcvm = var.v_srcvm
  v_tgtnode = var.v_tgtnode
  v_pool = var.v_pool
  v_nameserver = var.v_nameserver
  v_searchdomain = var.v_searchdomain

  v_sockets = var.v_sockets
  v_cores = var.v_cores
  v_memory = var.v_memory

}

