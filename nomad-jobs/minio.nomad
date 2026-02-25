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

      # Load secrets from file on the host
      template {
        data = <<EOH
{{ with file "/etc/nomad.d/secrets/minio.env" -}}
{{ . }}
{{- end }}
EOH
        destination = "secrets/minio.env"
        env         = true
      }

      env {
        MINIO_BROWSER = "on"
      }

      resources {
        cpu    = 1000  # 1 CPU
        memory = 2048  # 2 GB RAM
      }

      service {
        name = "minio-api"
        port = "api"
        
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
