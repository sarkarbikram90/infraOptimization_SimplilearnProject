# Define provider configuration
provider "google" {
  credentials = file("C:\\Users\\bikrams\\infraoptimize2023-62ae5bce0d52.json") # Service Account key path
  project     = "infraoptimize2023"
  region      = "us-central1"
}

# Create static ips for VM instances
resource "google_compute_address" "static_ips" {
  count    = 3
  name     = "static-ip-${count.index}"
  region   = "us-central1"
}

# Create three VM instances
resource "google_compute_instance" "vms" {
  count        = 3
  name         = "instance-${count.index + 1}" # Instance Count
  machine_type = "n1-standard-1" # Machine type
  zone         = "us-central1-b" # Deployment zone

  # Define the image ubuntu 18.04 LTS
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  # Define network interface for static ips
  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.static_ips[count.index].address
    }
  }
}

# Create firewall rules to allow SSH, HTTP, and HTTPS traffic
resource "google_compute_firewall" "ssh" {
  name        = "allow-ssh"
  network     = "default"
  direction   = "INGRESS"
  target_tags = ["allow-ssh"]
  
  source_tags = ["allow-ssh"]  

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "http" {
  name        = "allow-http"
  network     = "default"
  direction   = "INGRESS"
  target_tags = ["allow-http"]

  source_tags = ["allow-http"]  

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
}

resource "google_compute_firewall" "https" {
  name        = "allow-https"
  network     = "default"
  direction   = "INGRESS"
  target_tags = ["allow-https"]

  source_tags = ["allow-https"]  

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

# Together, these resources configure an HTTP load balancer that distributes traffic to the VMs based on the defined health checks and routing rules.
# Define the load balancing configuration for the VMs
resource "google_compute_http_health_check" "health_check" { # google_compute_http_health_check: This resource defines an HTTP health check. It periodically sends HTTP request to the VMs to verify their health.
  name               = "my-health-check"
  check_interval_sec = 5
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 2
  request_path       = "/"
}

resource "google_compute_instance_group" "vm_group" { # google_compute_instance_group: This resource defines an instance group and associates it with the VMs. The instance group represents a pool of VMs that will be load balanced.
  name = "my-vm-group"
  zone = "us-central1-b"
  instances = google_compute_instance.vms.*.self_link
}

resource "google_compute_backend_service" "backend_service" { # google_compute_backend_service: This resource defines the backend service, which represents the group of VMs that will serve the traffic. It specifies the instance group as the backend and associates the HTTP health check with it.
  name = "my-backend-service"
  port_name = "http"
  protocol = "HTTP"

  backend {
    group = google_compute_instance_group.vm_group.self_link
  }

  health_checks = [
    google_compute_http_health_check.health_check.self_link
  ]
}

resource "google_compute_url_map" "url_map" { # google_compute_url_map: This resource defines the URL map, which directs incoming requests to the appropriate backend service based on the requested URL.
  name            = "my-url-map"
  default_service = google_compute_backend_service.backend_service.self_link
}

resource "google_compute_target_http_proxy" "http_proxy" { # google_compute_target_http_proxy: This resource defines the target HTTP proxy, which represents the load balancer. It associates the URL map with the proxy.
  name    = "my-http-proxy"
  url_map = google_compute_url_map.url_map.self_link
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" { # google_compute_global_forwarding_rule: This resource defines the forwarding rule, which maps external traffic to the load balancer. It specifies the target HTTP proxy and the port range (in this case, port 80).
  name       = "my-forwarding-rule"
  target     = google_compute_target_http_proxy.http_proxy.self_link
  port_range = "80"
}

# Together, these resources configure an HTTP load balancer that distributes traffic to the VMs based on the defined health checks and routing rules.