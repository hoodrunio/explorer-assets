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

# Kullanıcıdan Private Key bilgilerini al
echo -e "\033[33mLütfen CLI Node Private Key'inizi girin:\033[0m"
read -r PRIVATE_KEY

# 3 saniye bekleme
echo "Kurulum başlıyor..."
sleep 3

echo "Sistem güncelleniyor..."
sudo apt update && sudo apt upgrade -y

echo "Bağımlılıklar kuruluyor..."
sudo apt update && sudo apt install -y build-essential clang pkg-config

echo "Go kuruluyor..."
wget https://go.dev/dl/go1.22.1.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.22.1.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> $HOME/.profile
source $HOME/.profile
go version
# Temizlik
rm -f go1.22.1.linux-amd64.tar.gz

echo "Repo klonlanıyor..."
git clone https://github.com/Layer-Edge/light-node.git
cd light-node

echo "Ortam değişkenleri ayarlanıyor..."
cat <<EOF > .env
GRPC_URL=grpc.testnet.layeredge.io:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=https://layeredge.mintair.xyz/
API_REQUEST_TIMEOUT=100
POINTS_API=https://light-node.layeredge.io
PRIVATE_KEY='$PRIVATE_KEY'
EOF

echo "Light node yükleniyor"
go build
sleep 3

echo "Light Node Servis dosyası oluşturuluyor..."
sudo tee /etc/systemd/system/layer-edge.service <<EOF
[Unit]
Description=Layer Edge Light Node
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$HOME/light-node
ExecStart=$HOME/light-node/light-node
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
echo -e "\033[34mLogları görüntülemek için:\033[0m"
echo -e "\033[33mLight Node:\033[0m journalctl -fo cat -u layer-edge \033[35m(yüklenmesi için biraz bekleyin)\033[0m"
echo -e "\033[34mServis durumunu kontrol etmek için:\033[0m sudo systemctl status layer-edge"
