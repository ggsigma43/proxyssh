#!/bin/bash

# Download and setup autostart
curl -o /root/socks5_proxy.py https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/socks5_proxy.py

# Create systemd service
cat > /etc/systemd/system/socks5-proxy.service << EOF
[Unit]
Description=SOCKS5 Proxy Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/bin/python3 /root/socks5_proxy.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable socks5-proxy.service
systemctl start socks5-proxy.service

echo "[+] SOCKS5 proxy installed and configured for autostart"
