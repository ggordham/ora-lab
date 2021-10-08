provider "proxmox" {
  # Configuration options
  pm_api_url = "https://MYSERVER.COM:8006/api2/json"
  pm_user = "MYAPI_USER@REALM"
  pm_tls_insecure = true
}

