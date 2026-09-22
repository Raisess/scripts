#!/bin/bash

# Ensure script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run this script with sudo: sudo ./setup-tunnel.sh"
  exit 1
fi

read -p "Enter a custom name for your service (e.g., cloudflared-app2): " SERVICE_NAME
read -p "Enter your Cloudflare Tunnel Token: " TUNNEL_TOKEN

if [ -z "$SERVICE_NAME" ] || [ -z "$TUNNEL_TOKEN" ]; then
  echo "[-] Error: Service name and tunnel token cannot be empty."
  exit 1
fi

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo "[+] Creating systemd service file at $SERVICE_FILE..."
cat << EOL > "$SERVICE_FILE"
[Unit]
Description=Cloudflare Tunnel ($SERVICE_NAME)
After=network.target

[Service]
TimeoutStartSec=0
Type=notify
ExecStart=/usr/bin/cloudflared tunnel --no-autoupdate run --token $TUNNEL_TOKEN
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOL

echo "[+] Reloading systemd daemon..."
systemctl daemon-reload

echo "[+] Enabling and starting $SERVICE_NAME..."
systemctl enable --now "$SERVICE_NAME"

echo "[+] Done! Checking service status:"
systemctl status "$SERVICE_NAME" --no-pager
