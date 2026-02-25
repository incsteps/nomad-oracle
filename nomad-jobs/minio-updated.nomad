job "minio" {
  datacenters = ["dc1"]
  type        = "service"

  group "minio" {
    count = 1

    network {
      port "api" {
        static = 9000
        to     = 9000
      }
      port "console" {
        static = 9001
        to     = 9001
      }
    }

    task "minio-server" {
      driver = "docker"

      config {
        image = "minio/minio:latest"
        ports = ["api", "console"]
        
        args = [
          "server",
          "/data",
          "--console-address",
          ":9001"
        ]

        volumes = [
          "/mnt/minio-data:/data"
        ]
      }

      env {
        MINIO_ROOT_USER     = "TUIe4l4qklLa"
        MINIO_ROOT_PASSWORD = "KoEjVCovFTTJpfdaoI6PDzkY5H3cvzNV"
        MINIO_BROWSER       = "on"
      }

      resources {
        cpu    = 2000  # 2 CPUs
        memory = 4096  # 4 GB RAM
      }

      service {
        name = "minio-api"
        port = "api"
        provider = "nomad"
        
        tags = [
          "minio",
          "s3",
          "storage"
        ]

        check {
          type     = "http"
          path     = "/minio/health/live"
          interval = "10s"
          timeout  = "2s"
        }
      }

      service {
        name = "minio-console"
        port = "console"
        provider = "nomad"
        
        tags = [
          "minio",
          "console",
          "ui"
        ]

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
