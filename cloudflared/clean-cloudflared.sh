#!/bin/bash

read -p "Enter a custom name for your service (e.g., cloudflared-app2): " SERVICE_NAME
if [ -z "$SERVICE_NAME" ]; then
  echo "[-] Error: Service name cannot be empty."
  exit 1
fi

SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo "Stopping cloudflared $SERVICE_NAME service..."
sudo systemctl stop $SERVICE_NAME 2>/dev/null

echo "Removing service files..."
sudo rm -f $SERVICE_FILE

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload
sudo systemctl reset-failed

echo "$SERVICE_NAME cloudflared cleanup complete!"
