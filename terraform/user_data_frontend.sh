#!/bin/bash
set -euxo pipefail

BACKEND_PRIVATE_IP="${backend_private_ip}"
FRONTEND_IMAGE="${frontend_image}"

apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release nginx

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker ubuntu

# ---------------- Frontend container (listens on host :3000) ----------------
docker pull "$FRONTEND_IMAGE" || echo "Image not pre-built; build manually if needed."

docker run -d \
  --name app_frontend \
  --restart unless-stopped \
  -p 3000:80 \
  "$FRONTEND_IMAGE" || true

# ---------------- Host NGINX reverse proxy ----------------
cat > /etc/nginx/sites-available/app <<EOF
upstream frontend_app { server 127.0.0.1:3000; }
upstream backend_api  { server ${BACKEND_PRIVATE_IP}:5000; }

server {
    listen 80 default_server;
    server_name _;
    client_max_body_size 10m;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    location /api/ {
        proxy_pass         http://backend_api/api/;
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }

    location = /healthz { return 200 "ok\n"; add_header Content-Type text/plain; }

    location / {
        proxy_pass         http://frontend_app;
        proxy_http_version 1.1;
        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
systemctl enable nginx

echo "Frontend EC2 bootstrap complete."
