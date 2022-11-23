provider "proxmox" {
  # Configuration options
  pm_api_url = "https://pve02.gg.wi.rr.com:8006/api2/json"
  pm_user = "terraform-user@pve"
  pm_tls_insecure = true
}


