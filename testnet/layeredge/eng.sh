#!/bin/bash

# ASCII Art and Let's Build text
echo -e "\033[32m"
echo "_    _                 _ _____             "
echo "| |  | |               | |  __ \            "
echo "| |__| | ___   ___   __| | |__) |   _ _ __  "
echo "|  __  |/ _ \ / _ \ / _\` |  _  / | | | '_ \ "
echo "| |  | | (_) | (_) | (_| | | \ \ |_| | | | |"
echo "|_|  |_|\___/ \___/ \__,_|_|  \_\__,_|_| |_| lets build..."
echo -e "\033[0m"

# Prompt for the user's Private Key
echo -e "\033[33mPlease enter your CLI Node Private Key:\033[0m"
read -r PRIVATE_KEY

# Wait for 3 seconds
echo "Installation is starting..."
sleep 3

# Update the system
echo "Updating the system..."
sudo apt update && sudo apt upgrade -y

# Install dependencies
echo "Installing dependencies..."
sudo apt update && sudo apt install -y build-essential clang pkg-config

# Install Docker
echo "Installing Docker..."
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker $(whoami)
docker --version

# Install Go
echo "Installing Go..."
wget https://go.dev/dl/go1.22.1.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.22.1.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> $HOME/.profile
source $HOME/.profile
go version
# Cleanup
rm -f go1.22.1.linux-amd64.tar.gz

# Install Rust and Risc0
echo "Installing Rust and Risc0..."
curl -L https://sh.rustup.rs -o rustup-init.sh
chmod +x rustup-init.sh
./rustup-init.sh -y
source "$HOME/.cargo/env"

# Download Risc0 installation files
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

# Refresh shell
source $HOME/.profile
if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi
if [ -f "$HOME/.zshrc" ]; then
    source "$HOME/.zshrc"
fi

# Cleanup
rm -f rustup-init.sh risc0-install.sh

# Install Risc0 tools
echo "Installing Risc0 tools..."
export PATH="$HOME/.risc0/bin:$PATH"
rzup install
rzup --version

# Clone the repository
echo "Cloning the repository..."
git clone https://github.com/Layer-Edge/light-node.git
cd light-node

# Set environment variables
echo "Setting environment variables..."
cat <<EOF > .env
GRPC_URL=34.31.74.109:9090
CONTRACT_ADDR=cosmos1ufs3tlq4umljk0qfe8k5ya0x6hpavn897u2cnf9k0en9jr7qarqqt56709
ZK_PROVER_URL=http://127.0.0.1:3001
API_REQUEST_TIMEOUT=100
POINTS_API=http://127.0.0.1:8080
PRIVATE_KEY='$PRIVATE_KEY'
EOF

# Prepare Risc0 and Light Node
echo "Preparing Risc0 and Light Node..."
cd $HOME/light-node
chmod +x scripts/build-risczero.sh
export PATH="$HOME/.risc0/bin:$PATH"
./scripts/build-risczero.sh
if [ $? -ne 0 ]; then
    echo "Risc0 build error. Please check the error messages."
    exit 1
fi
sleep 5
go build

# Create Risc0 service file
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

# Create Light Node service file
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

# Start the services
echo "Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable layer-edge
sudo systemctl start layer-edge

echo -e "\033[32mInstallation completed!\033[0m"
echo -e "\033[34mTo view logs:\033[0m"
echo -e "\033[33mLight Node:\033[0m journalctl -fo cat -u layer-edge \033[35m(please wait for loading)\033[0m"
echo -e "\033[33mRisc0:\033[0m journalctl -fo cat -u risc0 \033[35m(please wait for loading)\033[0m"
echo -e "\033[34mTo check service status:\033[0m sudo systemctl status layer-edge"
