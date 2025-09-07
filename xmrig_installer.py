#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import subprocess
import requests
import tarfile
import zipfile
import platform
import json
from pathlib import Path

# Конфигурация
XMR_WALLET = "87N1Fb1gkypZgnPB4ysPXj3L1J8YR7EK2JpLJX9w6yDpVs7FXUJH7zc996sbnhJ3sU51MrBzTPLMJW8JCmJehNci9E8Jw5N"
POOL_URL = "pool.hashvault.pro:443"

class XMRigInstaller:
    def __init__(self):
        self.home_dir = Path.home()
        self.miner_dir = self.home_dir / "xmrig_miner"
        self.arch = platform.machine().lower()
        self.system = platform.system().lower()
        
    def detect_architecture(self):
        """Определяем архитектуру"""
        arch_map = {
            'x86_64': 'x64',
            'amd64': 'x64', 
            'i386': 'x86',
            'i686': 'x86',
            'armv7l': 'armhf',
            'armv8l': 'arm64',
            'aarch64': 'arm64',
            'arm64': 'arm64'
        }
        return arch_map.get(self.arch, 'x64')
    
    def get_download_url(self):
        """Получаем URL для скачивания XMRig"""
        arch = self.detect_architecture()
        version = "6.20.0"
        
        if self.system == "linux":
            return f"https://github.com/xmrig/xmrig/releases/download/v{version}/xmrig-{version}-linux-static-{arch}.tar.gz"
        elif self.system == "windows":
            return f"https://github.com/xmrig/xmrig/releases/download/v{version}/xmrig-{version}-msvc-win64.zip"
        else:
            return f"https://github.com/xmrig/xmrig/releases/download/v{version}/xmrig-{version}-generic-static.tar.gz"
    
    def download_file(self, url, filename):
        """Скачиваем файл"""
        try:
            print(f"[+] Downloading {url}")
            response = requests.get(url, stream=True, timeout=30)
            response.raise_for_status()
            
            with open(filename, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            return True
        except Exception as e:
            print(f"[-] Download failed: {e}")
            return False
    
    def extract_archive(self, filename):
        """Распаковываем архив"""
        try:
            print(f"[+] Extracting {filename}")
            
            if filename.endswith('.tar.gz'):
                with tarfile.open(filename, 'r:gz') as tar:
                    tar.extractall(self.miner_dir)
            elif filename.endswith('.zip'):
                with zipfile.ZipFile(filename, 'r') as zip_ref:
                    zip_ref.extractall(self.miner_dir)
            else:
                print("[-] Unknown archive format")
                return False
                
            return True
        except Exception as e:
            print(f"[-] Extraction failed: {e}")
            return False

    def create_config(self):
        """Создаем конфигурационный файл для HashVault с автонастройкой памяти"""
        # Автоматически определяем доступную память
        try:
            with open('/proc/meminfo', 'r') as f:
                meminfo = f.read()
            total_mem_kb = int([line for line in meminfo.split('\n') if 'MemTotal:' in line][0].split()[1])
            total_mem_gb = total_mem_kb / 1024 / 1024
            
            # Настройки в зависимости от доступной памяти
            if total_mem_gb >= 16:
                # Много RAM - используем 1GB pages и полный режим
                rx_mode = "auto"
                use_1gb_pages = True
                memory_percent = 80  # Используем 80% памяти
            elif total_mem_gb >= 8:
                # Среднее количество RAM - balanced режим
                rx_mode = "auto" 
                use_1gb_pages = False
                memory_percent = 70
            elif total_mem_gb >= 4:
                # Мало RAM - light режим
                rx_mode = "light"
                use_1gb_pages = False
                memory_percent = 60
            else:
                # Очень мало RAM - ultra light режим
                rx_mode = "light"
                use_1gb_pages = False
                memory_percent = 50
                
            print(f"[+] Detected {total_mem_gb:.1f} GB RAM, using {memory_percent}% for mining")
            
        except:
            # Если не смогли определить память - безопасные настройки по умолчанию
            rx_mode = "auto"
            use_1gb_pages = False
            memory_percent = 50
            print("[+] Using default memory settings")

        config = {
            "autosave": True,
            "cpu": True,
            "opencl": False,
            "cuda": False,
            "randomx": {
                "1gb-pages": use_1gb_pages,
                "mode": rx_mode
            },
            "cpu": {
                "max-threads-hint": 100,
                "priority": 5,
                "memory": memory_percent
            },
            "msr": True,
            "huge-pages": True,
            "pools": [
                {
                    "coin": "monero",
                    "algo": "rx/0",
                    "url": POOL_URL,
                    "user": XMR_WALLET,
                    "pass": "x",
                    "tls": True,
                    "keepalive": True,
                    "nicehash": False
                }
            ],
            "api": {
                "port": 0,
                "access-token": None,
                "ipv6": False,
                "restricted": True
            },
            "background": False,
            "log-file": str(self.miner_dir / "xmrig.log"),
            "print-time": 60,
            "health-print-time": 60,
            "retries": 5,
            "retry-pause": 5,
            "max-cpu-usage": 100,
            "cpu-memory-pool": 1,
            "dataset-host": False
        }
        
        config_path = self.miner_dir / "config.json"
        try:
            with open(config_path, 'w') as f:
                json.dump(config, f, indent=4)
            print(f"[+] Config created: {config_path}")
            print(f"[+] Memory settings: {rx_mode} mode, 1GB-pages: {use_1gb_pages}")
            return True
        except Exception as e:
            print(f"[-] Config creation failed: {e}")
            return False
    
    def make_executable(self):
        """Делаем файлы исполняемыми"""
        try:
            for file in self.miner_dir.glob("xmrig*"):
                if file.is_file() and not file.suffix:
                    file.chmod(0o755)
                    print(f"[+] Made executable: {file.name}")
                    return str(file)
            
            # Если не нашли, ищем в поддиректориях
            for file in self.miner_dir.rglob("xmrig*"):
                if file.is_file() and not file.suffix:
                    file.chmod(0o755)
                    print(f"[+] Made executable: {file.name}")
                    return str(file)
                    
            return None
        except Exception as e:
            print(f"[-] Failed to make executable: {e}")
            return None
    
    def install_dependencies(self):
        """Устанавливаем зависимости"""
        try:
            if self.system == "linux":
                # Пробуем разные пакетные менеджеры
                try:
                    subprocess.run(['apt', 'update'], check=True, capture_output=True)
                    subprocess.run(['apt', 'install', '-y', 'curl', 'wget'], check=True, capture_output=True)
                except:
                    try:
                        subprocess.run(['yum', 'install', '-y', 'curl', 'wget'], check=True, capture_output=True)
                    except:
                        try:
                            subprocess.run(['apk', 'add', 'curl', 'wget'], check=True, capture_output=True)
                        except:
                            print("[-] Could not install dependencies automatically")
            return True
        except Exception as e:
            print(f"[-] Dependency installation failed: {e}")
            return False
    
    def run_miner(self):
        """Запускаем майнер"""
        try:
            miner_binary = self.make_executable()
            if not miner_binary:
                print("[-] Could not find miner binary")
                return False
            
            config_file = self.miner_dir / "config.json"
            
            print(f"[+] Starting XMRig with wallet: {XMR_WALLET}")
            print(f"[+] Pool: {POOL_URL}")
            print(f"[+] Binary: {miner_binary}")
            
            # Запускаем майнер
            cmd = [miner_binary, "-c", str(config_file)]
            process = subprocess.Popen(cmd, cwd=str(self.miner_dir))
            
            print("[+] Miner started successfully!")
            print("[+] Press Ctrl+C to stop mining")
            
            # Ждем завершения
            process.wait()
            return True
            
        except KeyboardInterrupt:
            print("\n[+] Mining stopped by user")
            return True
        except Exception as e:
            print(f"[-] Failed to start miner: {e}")
            return False
    
    def install_and_run(self):
        """Основной метод установки и запуска"""
        print("=" * 50)
        print("XMRig Auto-Installer")
        print("=" * 50)
        print(f"Wallet: {XMR_WALLET}")
        print(f"Pool: {POOL_URL}")
        print(f"System: {self.system} {self.arch}")
        print("=" * 50)
        
        # Создаем директорию
        self.miner_dir.mkdir(exist_ok=True)
        os.chdir(self.miner_dir)
        
        # Устанавливаем зависимости
        if not self.install_dependencies():
            print("[-] Continuing without dependencies...")
        
        # Скачиваем XMRig
        download_url = self.get_download_url()
        filename = "xmrig.tar.gz" if ".tar.gz" in download_url else "xmrig.zip"
        
        if not self.download_file(download_url, filename):
            print("[-] Download failed, please check your internet connection")
            return False
        
        # Распаковываем
        if not self.extract_archive(filename):
            print("[-] Extraction failed")
            return False
        
        # Создаем конфиг
        if not self.create_config():
            print("[-] Config creation failed")
            return False
        
        # Запускаем майнер
        return self.run_miner()

def main():
    """Точка входа"""
    try:
        installer = XMRigInstaller()
        success = installer.install_and_run()
        
        if success:
            print("[+] Installation and mining completed successfully!")
        else:
            print("[-] Installation failed")
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n[+] Installation cancelled by user")
    except Exception as e:
        print(f"[-] Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
