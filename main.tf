terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

provider "docker" {}

# Docker Network
resource "docker_network" "monitoring" {
  name = "monitoring-network"
}

# Minecraft imagee
resource "docker_image" "minecraft" {
  name = "itzg/minecraft-server:latest"
}

# Minecraft container
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

  # To expose exporter for prometheus
  ports {
    internal = 9225
    external = 9225
  }

  volumes {
    host_path = "${path.cwd}/minecraft/data"
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

# Prometheus image
resource "docker_image" "prometheus" {
  name = "prom/prometheus:latest"  
}

# Prometheus container
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
    host_path      = "${path.cwd}/prometheus/prometheus.yml"
    container_path = "/etc/prometheus/prometheus.yml"
  }

}

# Grafana image
resource "docker_image" "grafana" {
  name = "grafana/grafana-enterprise"
}

# Grafana container
resource "docker_container" "grafana" {
  name = "grafana"
  image = docker_image.grafana.image_id

  networks_advanced {
    name = docker_network.monitoring.name
  }

  ports {
    internal = 3000
    external = 3000
  }
}

# resource "local_file" "grafana_datasource" {
#   content = <<-EOT
# apiVersion: 1

# datasources:
#   - name: Prometheus
#     type: prometheus
#     access: proxy
#     url: http://prometheus:9090
#     isDefault: true
#     editable: true
# EOT

#   filename = "${path.cwd}\\grafana\\grafana-provisioning\\datasources\\prometheus.yml"
# }