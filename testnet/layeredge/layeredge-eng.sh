#!/bin/bash

# ASCII Art and Lets Build text
echo -e "\033[32m"
echo "_    _                 _ _____             "
echo "| |  | |               | |  __ \            "
echo "| |__| | ___   ___   __| | |__) |   _ _ __  "
echo "|  __  |/ _ \ / _ \ / _\` |  _  / | | | '_ \ "
echo "| |  | | (_) | (_) | (_| | | \ \ |_| | | | |"
echo "|_|  |_|\___/ \___/ \__,_|_|  \_\__,_|_| |_| lets build..."
echo -e "\033[0m"

# 3 second wait
echo "Installation starting..."
sleep 3

echo "Updating system..."
sudo apt update && sudo apt upgrade -y

echo "Installing dependencies..."
sudo apt update && sudo apt install -y build-essential clang pkg-config

echo "Installing Docker..."
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $(whoami)
docker --version

echo "Installing Go..."
wget https://go.dev/dl/go1.22.1.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.22.1.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> $HOME/.profile
source $HOME/.profile
go version

echo "Installing Rust and Risc0..."
curl -L https://sh.rustup.rs -o rustup-init.sh
chmod +x rustup-init.sh
./rustup-init.sh -y
source "$HOME/.cargo/env"
curl -L https://risczero.com/install | bash
source "$HOME/.bashrc"
rzup install
rzup --version

echo "Cloning repository..."
git clone https://github.com/Layer-Edge/light-node.git
cd light-node

echo "Setting environment variables..."
cat <<EOF > .env
GRPC_URL=34.31.74.109:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=http://127.0.0.1:3001
API_REQUEST_TIMEOUT=100
EOF

echo "Preparing execution script..."
cd $HOME/light-node
chmod +x scripts/light-node-runner.sh

echo "Creating service file..."
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

echo "Starting service..."
sudo systemctl daemon-reload
sudo systemctl enable layer-edge
sudo systemctl start layer-edge

echo -e "\033[32mInstallation completed!\033[0m"
echo "To view logs: journalctl -fo cat -u layer-edge (wait a bit for it to load)"
echo "To check service status: sudo systemctl status layer-edge"
