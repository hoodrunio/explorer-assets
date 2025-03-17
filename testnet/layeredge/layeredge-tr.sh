#!/bin/bash

# ASCII Art ve Lets Build yazısı
echo -e "\033[32m"
echo "_    _                 _ _____             "
echo "| |  | |               | |  __ \            "
echo "| |__| | ___   ___   __| | |__) |   _ _ __  "
echo "|  __  |/ _ \ / _ \ / _\` |  _  / | | | '_ \ "
echo "| |  | | (_) | (_) | (_| | | \ \ |_| | | | |"
echo "|_|  |_|\___/ \___/ \__,_|_|  \_\__,_|_| |_| lets build..."
echo -e "\033[0m"

# Kullanıcıdan Private Key ve Public Key bilgilerini al
echo -e "\033[33mLütfen CLI Node Private Key'inizi girin:\033[0m"
read -r PRIVATE_KEY

echo -e "\033[33mLütfen Dashboard Wallet Public Key'inizi girin:\033[0m"
read -r PUBLIC_KEY

# 3 saniye bekleme
echo "Kurulum başlıyor..."
sleep 3

echo "Sistem güncelleniyor..."
sudo apt update && sudo apt upgrade -y

echo "Bağımlılıklar kuruluyor..."
sudo apt update && sudo apt install -y build-essential clang pkg-config

echo "Docker kuruluyor..."
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $(whoami)
docker --version

echo "Go kuruluyor..."
wget https://go.dev/dl/go1.22.1.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.22.1.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> $HOME/.profile
source $HOME/.profile
go version

echo "Rust ve Risc0 kuruluyor..."
curl -L https://sh.rustup.rs -o rustup-init.sh
chmod +x rustup-init.sh
./rustup-init.sh -y
source "$HOME/.cargo/env"
curl -L https://risczero.com/install | bash
source "$HOME/.bashrc"
rzup install
rzup --version

echo "Repoyu klonlanıyor..."
git clone https://github.com/Layer-Edge/light-node.git
cd light-node

echo "Ortam değişkenleri ayarlanıyor..."
cat <<EOF > .env
GRPC_URL=34.31.74.109:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=http://127.0.0.1:3001
API_REQUEST_TIMEOUT=100
POINTS_API=http://127.0.0.1:8080
PRIVATE_KEY='$PRIVATE_KEY'
PUBLIC_KEY='$PUBLIC_KEY'
EOF

echo "Çalıştırma scripti hazırlanıyor..."
cd $HOME/light-node
chmod +x scripts/light-node-runner.sh

echo "Servis dosyası oluşturuluyor..."
sudo tee /etc/systemd/system/layer-edge.service <<EOF
[Unit]
Description=Layer Edge Light Node
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$HOME/light-node
ExecStart=/bin/bash -c 'source $HOME/.bashrc && source $HOME/.bashrc && exec $HOME/light-node/scripts/light-node-runner.sh'
Restart=always
RestartSec=5
EnvironmentFile=$HOME/light-node/.env
Environment="PATH=/usr/local/go/bin:/usr/bin:/bin:$HOME/.cargo/bin:$HOME/.risc0/bin"

[Install]
WantedBy=multi-user.target
EOF

echo "Servis başlatılıyor..."
sudo systemctl daemon-reload
sudo systemctl enable layer-edge
sudo systemctl start layer-edge

echo -e "\033[32mKurulum tamamlandı!\033[0m"
echo "Logları görüntülemek için: journalctl -fo cat -u layer-edge (yüklenmesi için biraz bekleyin)"
echo "Servis durumunu kontrol etmek için: sudo systemctl status layer-edge"
