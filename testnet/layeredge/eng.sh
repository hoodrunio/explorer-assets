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

# Get Private Key from user
echo -e "\033[33mPlease enter your CLI Node Private Key:\033[0m"
read -r PRIVATE_KEY

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
# Cleanup
rm -f go1.22.1.linux-amd64.tar.gz

echo "Installing Rust and Risc0..."
curl -L https://sh.rustup.rs -o rustup-init.sh
chmod +x rustup-init.sh
./rustup-init.sh -y
source "$HOME/.cargo/env"

echo "Downloading Risc0 installation files..."
curl -L https://risczero.com/install -o risc0-install.sh
chmod +x risc0-install.sh
./risc0-install.sh

# Update PATH variables
echo 'export PATH="$HOME/.risc0/bin:$PATH"' >> $HOME/.profile
echo 'export PATH="$HOME/.risc0/bin:$PATH"' >> $HOME/.bashrc
if [ -f "$HOME/.zshrc" ]; then
    echo 'export PATH="$HOME/.risc0/bin:$PATH"' >> $HOME/.zshrc
fi

# Refresh shell source
source $HOME/.profile
if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi
if [ -f "$HOME/.zshrc" ]; then
    source "$HOME/.zshrc"
fi

# Cleanup
rm -f rustup-init.sh risc0-install.sh

echo "Installing Risc0 tools..."
export PATH="$HOME/.risc0/bin:$PATH"
rzup install
rzup --version

echo "Cloning repository..."
git clone https://github.com/Layer-Edge/light-node.git
cd light-node

echo "Setting environment variables..."
cat <<EOF > .env
GRPC_URL=grpc.testnet.layeredge.io:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=https://layeredge.mintair.xyz/
API_REQUEST_TIMEOUT=100
POINTS_API=https://light-node.layeredge.io
PRIVATE_KEY='$PRIVATE_KEY'
EOF

echo "Preparing Risc0 and Light Node..."
cd $HOME/light-node
chmod +x scripts/build-risczero.sh
export PATH="$HOME/.risc0/bin:$PATH"
./scripts/build-risczero.sh
if [ $? -ne 0 ]; then
    echo "Risc0 compilation error. Please check error messages."
    exit 1
fi
sleep 5
go build

echo "Creating Risc0 service file..."
sudo tee /etc/systemd/system/risc0.service <<EOF
[Unit]
Description=Risc0
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$HOME/light-node
ExecStart=$HOME/light-node/risc0-merkle-service/target/release/host
Restart=always
RestartSec=5
Environment="PATH=/usr/local/go/bin:/usr/bin:/bin:$HOME/.cargo/bin:$HOME/.risc0/bin"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable risc0
sudo systemctl start risc0

echo "Creating Light Node service file..."
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

echo "Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable layer-edge
sudo systemctl start layer-edge

echo -e "\033[32mInstallation completed!\033[0m"
echo -e "\033[34mTo view logs:\033[0m"
echo -e "\033[33mLight Node:\033[0m journalctl -fo cat -u layer-edge \033[35m(wait a bit for it to load)\033[0m"
echo -e "\033[33mRisc0:\033[0m journalctl -fo cat -u risc0 \033[35m(wait a bit for it to load)\033[0m"
echo -e "\033[34mTo check service status:\033[0m sudo systemctl status layer-edge"
