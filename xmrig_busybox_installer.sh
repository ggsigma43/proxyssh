#!/bin/sh
# Universal XMRig Installer for Linux (BusyBox compatible)
echo "[+] Installing XMRig Miner..."

# Create miner directory
echo "[+] Creating miner directory..."
mkdir -p /root/xmrig_miner
cd /root/xmrig_miner

# Detect architecture
ARCH=$(uname -m)
echo "[+] Detected architecture: $ARCH"

# Download URL based on architecture
case $ARCH in
    "mips"|"mipsel")
        echo "[+] MIPS architecture detected - using generic Linux build"
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-x64.tar.gz"
        ;;
    "aarch64"|"arm64")
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-arm64.tar.gz"
        ;;
    "armv7l"|"armhf")
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-armhf.tar.gz"
        ;;
    "i386"|"i686")
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-x86.tar.gz"
        ;;
    *)
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-x64.tar.gz"
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
    echo "[-] Download failed!"
    exit 1
fi

echo "[+] Extracting XMRig (BusyBox compatible)..."
# Extract without --strip-components for BusyBox
tar -xzf xmrig.tar.gz

# Find the binary (it might be in a subdirectory)
echo "[+] Finding XMRig binary..."
find . -name "xmrig" -type f | while read binary; do
    echo "[+] Found binary: $binary"
    cp "$binary" ./
    break
done

# Check if we found the binary
if [ -f "xmrig" ]; then
    chmod +x xmrig
    echo "[+] XMRig binary ready"
else
    echo "[-] Error: xmrig binary not found!"
    echo "[+] Contents of archive:"
    tar -tzf xmrig.tar.gz | head -20
    exit 1
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

echo "[+] Installation complete!"
echo "[+] ========================================="
echo "[+] XMRig Miner successfully installed!"
echo "[+] ========================================="
echo "[+] To start mining:"
echo "[+]   cd /root/xmrig_miner && ./xmrig -c config.json"
echo "[+] "
echo "[+] Press Ctrl+C to stop mining"
echo "[+] ========================================="

# Try to start miner
echo "[+] Attempting to start miner..."
if ./xmrig --version >/dev/null 2>&1; then
    echo "[+] Starting miner..."
    ./xmrig -c config.json
else
    echo "[-] Binary not compatible with this architecture"
    echo "[+] You may need to build from source for MIPS architecture"
fi
