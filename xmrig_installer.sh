#!/bin/sh
# Install script for XMRig Miner for OpenWrt
echo "[+] Installing XMRig Miner for OpenWrt..."

# Install dependencies
echo "[+] Updating package list..."
opkg update

echo "[+] Installing required packages..."
opkg install python3 python3-pip curl wget tar

# Download and install XMRig
echo "[+] Downloading XMRig..."
mkdir -p /root/xmrig_miner
cd /root/xmrig_miner

# Detect architecture and download correct version
ARCH=$(uname -m)
case $ARCH in
    "x86_64"|"amd64")
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-x64.tar.gz"
        ;;
    "i386"|"i686")
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-x86.tar.gz"
        ;;
    "aarch64"|"arm64")
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-arm64.tar.gz"
        ;;
    "armv7l"|"armhf")
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-armhf.tar.gz"
        ;;
    *)
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-x64.tar.gz"
        ;;
esac

echo "[+] Downloading XMRig for $ARCH..."
wget -O xmrig.tar.gz $XMRIG_URL

echo "[+] Extracting XMRig..."
tar -xzf xmrig.tar.gz --strip-components=1
chmod +x xmrig

# Create config file
echo "[+] Creating config file..."
cat > /root/xmrig_miner/config.json << 'END_CONFIG'
{
    "autosave": true,
    "cpu": true,
    "opencl": false,
    "cuda": false,
    "randomx": {
        "1gb-pages": false,
        "mode": "auto"
    },
    "cpu": {
        "max-threads-hint": 100,
        "priority": 5
    },
    "msr": true,
    "huge-pages": true,
    "pools": [
        {
            "coin": "monero",
            "algo": "rx/0",
            "url": "pool.hashvault.pro:443",
            "user": "87N1Fb1gkypZgnPB4ysPXj3L1J8YR7EK2JpLJX9w6yDpVs7FXUJH7zc996sbnhJ3sU51MrBzTPLMJW8JCmJehNci9E8Jw5N",
            "pass": "x",
            "tls": true,
            "keepalive": true,
            "nicehash": false
        }
    ],
    "api": {
        "port": 0,
        "access-token": null,
        "ipv6": false,
        "restricted": true
    },
    "background": false,
    "log-file": "/root/xmrig_miner/xmrig.log",
    "print-time": 60,
    "health-print-time": 60,
    "retries": 5,
    "retry-pause": 5
}
END_CONFIG

# Create startup script
echo "[+] Creating startup script..."
cat > /root/xmrig_miner/start_miner.sh << 'END_SCRIPT'
#!/bin/sh
# Simple script to start XMRig miner in screen
echo "[+] Starting XMRig miner in screen session..."
cd /root/xmrig_miner
screen -dmS xmrig-miner ./xmrig -c config.json
echo "[+] Screen session started: xmrig-miner"
echo "[+] To attach: screen -r xmrig-miner"
echo "[+] To detach: Ctrl+A then D"
echo "[+] Check logs: tail -f /root/xmrig_miner/xmrig.log"
END_SCRIPT

chmod +x /root/xmrig_miner/start_miner.sh

# Create init script for OpenWrt
echo "[+] Creating init script..."
cat > /etc/init.d/xmrig-miner << 'END_INIT'
#!/bin/sh /etc/rc.common

START=95
STOP=10

start_service() {
    echo "[+] Starting XMRig miner..."
    /root/xmrig_miner/start_miner.sh
}

stop_service() {
    echo "[+] Stopping XMRig miner..."
    screen -S xmrig-miner -X quit 2>/dev/null
    pkill -f "xmrig"
    sleep 2
    echo "[+] XMRig miner stopped"
}

restart_service() {
    stop_service
    sleep 2
    start_service
}

status_service() {
    if screen -list | grep -q "xmrig-miner"; then
        echo "[+] XMRig miner is running in screen session"
        screen -list
        echo "[+] Hashrate: check screen session or logs"
    else
        echo "[-] XMRig miner is not running"
    fi
}
END_INIT

# Make init script executable
chmod +x /etc/init.d/xmrig-miner

# Enable and start service
echo "[+] Enabling service..."
/etc/init.d/xmrig-miner enable

echo "[+] Starting service..."
/etc/init.d/xmrig-miner start

# Check status
echo "[+] Checking status..."
/etc/init.d/xmrig-miner status

# Create management scripts
echo "[+] Creating management scripts..."
cat > /usr/bin/miner-attach << 'END_SCRIPT'
#!/bin/sh
screen -r xmrig-miner
END_SCRIPT

cat > /usr/bin/miner-start << 'END_SCRIPT'
#!/bin/sh
/root/xmrig_miner/start_miner.sh
END_SCRIPT

cat > /usr/bin/miner-stop << 'END_SCRIPT'
#!/bin/sh
/etc/init.d/xmrig-miner stop
END_SCRIPT

cat > /usr/bin/miner-status << 'END_SCRIPT'
#!/bin/sh
/etc/init.d/xmrig-miner status
END_SCRIPT

cat > /usr/bin/miner-restart << 'END_SCRIPT'
#!/bin/sh
/etc/init.d/xmrig-miner restart
END_SCRIPT

cat > /usr/bin/miner-logs << 'END_SCRIPT'
#!/bin/sh
tail -f /root/xmrig_miner/xmrig.log
END_SCRIPT

chmod +x /usr/bin/miner-attach
chmod +x /usr/bin/miner-start
chmod +x /usr/bin/miner-stop
chmod +x /usr/bin/miner-status
chmod +x /usr/bin/miner-restart
chmod +x /usr/bin/miner-logs

# Final setup
echo "[+] Setting up permissions..."
chown -R root:root /root/xmrig_miner
chmod -R 755 /root/xmrig_miner

echo "[+] Installation complete!"
echo "[+] ========================================="
echo "[+] XMRig Miner successfully installed!"
echo "[+] ========================================="
echo "[+] Wallet: 87N1Fb1gkypZgnPB4ysPXj3L1J8YR7EK2JpLJX9w6yDpVs7FXUJH7zc996sbnhJ3sU51MrBzTPLMJW8JCmJehNci9E8Jw5N"
echo "[+] Pool: pool.hashvault.pro:443"
echo "[+] "
echo "[+] Management commands:"
echo "[+]   miner-start    - Start miner"
echo "[+]   miner-stop     - Stop miner"
echo "[+]   miner-restart  - Restart miner"
echo "[+]   miner-status   - Check status"
echo "[+]   miner-attach   - Attach to screen session"
echo "[+]   miner-logs     - View logs in real-time"
echo "[+] "
echo "[+] Config file: /root/xmrig_miner/config.json"
echo "[+] Log file: /root/xmrig_miner/xmrig.log"
echo "[+] ========================================="

# Run initial status check
echo "[+] Checking miner status..."
sleep 3
miner-status
