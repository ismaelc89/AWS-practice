#!/bin/bash
set -e

# Usage check
if [ -z "$1" ]; then
    echo "Error: Private EC2 IP address required."
    echo "Usage: ./setup_nginx.sh "
    exit 1
fi

PRIVATE_IP="$1"

echo "==> Installing and starting Nginx..."
sudo dnf install -y nginx
sudo systemctl enable --now nginx

echo "==> Backing up default nginx.conf..."
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak

echo "==> Creating reverse proxy configuration..."
sudo tee /etc/nginx/conf.d/reverse_proxy.conf > /dev/null << EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://${PRIVATE_IP}:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF