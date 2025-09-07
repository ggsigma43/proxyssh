#!/bin/sh
# Universal XMRig Installer for Linux
echo "[+] Installing XMRig Miner..."

# Detect package manager and install basic tools
if command -v apt >/dev/null 2>&1; then
    echo "[+] Using apt package manager"
    apt update
    apt install -y curl wget tar
elif command -v yum >/dev/null 2>&1; then
    echo "[+] Using yum package manager" 
    yum install -y curl wget tar
elif command -v opkg >/dev/null 2>&1; then
    echo "[+] Using opkg package manager"
    opkg update
    opkg install curl wget tar
else
    echo "[+] No package manager found, trying to continue with available tools"
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

# Create startup script
echo "[+] Creating startup script..."
cat > start_miner.sh << 'END_SCRIPT'
#!/bin/sh
cd /root/xmrig_miner
echo "[+] Starting XMRig miner..."
./xmrig -c config.json
END_SCRIPT

chmod +x start_miner.sh

# Create management script
cat > /usr/local/bin/xmrig-start << 'END_SCRIPT'
#!/bin/sh
cd /root/xmrig_miner
./start_miner.sh
END_SCRIPT

chmod +x /usr/local/bin/xmrig-start

echo "[+] Installation complete!"
echo "[+] ========================================="
echo "[+] XMRig Miner successfully installed!"
echo "[+] ========================================="
echo "[+] Wallet: 87N1Fb1gkypZgnPB4ysPXj3L1J8YR7EK2JpLJX9w6yDpVs7FXUJH7zc996sbnhJ3sU51MrBzTPLMJW8JCmJehNci9E8Jw5N"
echo "[+] Pool: pool.hashvault.pro:443"
echo "[+] "
echo "[+] To start mining:"
echo "[+]   cd /root/xmrig_miner && ./start_miner.sh"
echo "[+]   or: xmrig-start"
echo "[+] "
echo "[+] Press Ctrl+C to stop mining"
echo "[+] ========================================="

# Start miner automatically
echo "[+] Starting miner..."
cd /root/xmrig_miner
./start_miner.sh
