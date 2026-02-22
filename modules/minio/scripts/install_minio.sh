#!/bin/bash
set -euxo pipefail

# Variables pasadas desde Terraform
MINIO_DATA_PATH="${minio_data_path}"
FSS_MOUNT_TARGET_IP="${fss_mount_target_ip}"
FSS_EXPORT_PATH="${fss_export_path}"

apt update && apt upgrade -y

sudo mkdir -p $MINIO_DATA_PATH

if ! mountpoint -q "$MINIO_DATA_PATH"; then
  echo "Mounting FSS export $FSS_MOUNT_TARGET_IP:$FSS_EXPORT_PATH to $MINIO_DATA_PATH..."
  sudo mount -o nfsvers=3,defaults $FSS_MOUNT_TARGET_IP:$FSS_EXPORT_PATH $MINIO_DATA_PATH
  echo "$FSS_MOUNT_TARGET_IP:$FSS_EXPORT_PATH $MINIO_DATA_PATH nfs defaults,nofail,nfsvers=3 0 0" | sudo tee -a /etc/fstab
else
  echo "FSS export already mounted at $MINIO_DATA_PATH."
fi

groupadd -r minio-user
useradd -M -r -g minio-user minio-user
chown minio-user:minio-user $MINIO_DATA_PATH

wget https://dl.min.io/server/minio/release/linux-amd64/archive/minio_20250613113347.0.0_amd64.deb -O minio.deb
sudo dpkg -i minio.deb

sudo tee /etc/default/minio > /dev/null <<EOF

MINIO_ROOT_USER=${minio_access_key}
MINIO_ROOT_PASSWORD=${minio_secret_key}

# MINIO_VOLUMES sets the storage volume or path to use for the MinIO server.

MINIO_VOLUMES="$MINIO_DATA_PATH"

# MINIO_OPTS sets any additional commandline options to pass to the MinIO server.
# For example, `--console-address :9001` sets the MinIO Console listen port
MINIO_OPTS="--console-address :9001"
EOF

sudo iptables -I INPUT -p tcp --dport 9000 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 9001 -j ACCEPT
sudo iptables-save -f /etc/iptables/rules.v4


sudo systemctl daemon-reload
sudo systemctl enable minio.service
sudo systemctl start minio.service

curl https://dl.min.io/client/mc/release/linux-amd64/mc \
  --create-dirs \
  -o ~/minio-binaries/mc
chmod +x ~/minio-binaries/mc
echo -en "PATH=\$PATH:~/minio-binaries/ PATH" >> ~/.bash_profile


curl -fsSL https://tailscale.com/install.sh | sh
# tailscale up --login-server https://your.domain.com --force-reauth

echo "MinIO installation and setup complete, using FSS for data!"