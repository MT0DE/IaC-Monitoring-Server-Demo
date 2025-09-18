terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

provider "docker" {
  host = "npipe:////.//pipe//docker_engine"
}

resource "docker_network" "monitoring" {
  name = "monitoring-network"
}

# Prometheus specific
resource "docker_image" "prometheus" {
  name = "prom/prometheus:latest"  
}

resource "local_file" "prometheus_config" {
  filename = "${path.module}\\prometheus\\prometheus.yml"
  content = <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'minecraft'
    static_config:
      - targets: ['localhost:9225']
      
  # Example for scraping Docker containers
  - job_name: 'docker'
    static_configs:
      - targets: ['host.docker.internal:9323']
EOF
}

resource "docker_container" "prometheus" {
  name = "prometheus"
  image = docker_image.prometheus.image_id 
  
  ports {
    internal = 9090
    external = 9090
  }
  
  networks_advanced {
    name = docker_network.monitoring.name
  }

  volumes {
    host_path      = "${path.cwd}\\prometheus\\prometheus.yml"
    container_path = "/etc/prometheus/prometheus.yml"
    read_only      = true
  }
  
  volumes {
    host_path      = "${path.cwd}\\prometheus\\prometheus-data"
    container_path = "/prometheus"
  }
  
  restart = "unless-stopped"
}

# Grafana Specific
resource "docker_image" "grafana" {
  name = "grafana/grafana-enterprise"
}
resource "docker_container" "grafana" {
  name = "grafana-for-prometheus"
  image = docker_image.grafana.image_id

  networks_advanced {
    name = docker_network.monitoring.name
  }

  ports {
    internal = 3000
    external = 3000
  }

  env = [
    "GF_SECURITY_ADMIN_PASSWORD=admin123",
    "GF_USERS_ALLOW_SIGN_UP=false"
  ]
  
  volumes {
    host_path      = "${path.cwd}\\grafana\\grafana-data"
    container_path = "/var/lib/grafana"
  }
  
  volumes {
    host_path      = "${path.cwd}\\grafana\\grafana-provisioning"
    container_path = "/etc/grafana/provisioning"
    read_only      = true
  }
  
  restart = "unless-stopped"

  depends_on = [docker_container.prometheus]
}

resource "local_file" "grafana_datasource" {
  content = <<-EOT
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOT

  filename = "${path.cwd}\\grafana\\grafana-provisioning\\datasources\\prometheus.yml"
}

# Minecraft specific
resource "docker_image" "minecraft" {
  name = "itzg/minecraft-server:latest"
}
resource "docker_container" "minecraft" {
  name  = "minecraft-server"
  image = docker_image.minecraft.image_id

  networks_advanced {
    name = docker_network.monitoring.name
  }

  ports {
    internal = 25565
    external = 25565
  }

  ports {
    internal = 9225
    external = 9225
  }

  volumes {
    host_path = "${path.cwd}\\data"
    container_path = "/data"
  }
  
  env = [
    "EULA=TRUE",                  # Must accept Minecraft EULA
    "MEMORY=4G",                  # Allocate 4GB RAM
    "DIFFICULTY=hard",            # easy/normal/hard
    "ONLINE_MODE=TRUE",           # Only allow premium accounts
    "MAX_PLAYERS=20",             # Max players
    "MOTD=Terraform Minecraft!",  # Server description
    "TYPE=FORGE"                  # Forge serrver declaration
  ]
}

# Meta
resource "null_resource" "create_directories" {
  provisioner "local-exec" {
    command = "mkdir -p prometheus & mkdir -p prometheus\\prometheus-data & mkdir -p grafana &mkdir -p grafana\\grafana-data & mkdir -p grafana\\grafana-provisioning\\datasources & mkdir -p grafana\\grafana-provisioning\\dashboards"
  }
}

resource "null_resource" "copy_static_file" {
  provisioner "local-exec" {
    command = "copy ${path.cwd}\\16508_rev1.json ${path.cwd}\\grafana\\grafana-provisioning\\dashboards\\"
  }
  depends_on = [ null_resource.create_directories ]
}
