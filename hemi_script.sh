#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

check_version() {
    local latest_version=$(curl -s https://api.github.com/repos/hemilabs/heminetwork/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
    echo $latest_version
}

auto_update() {
    local current_version="0.7.0"
    local latest_version=$(check_version)
    
    if [[ "$current_version" != "$latest_version" ]]; then
        echo -e "${YELLOW}New version available: ${latest_version}${NC}"
        
        cp ~/hemi/popmd.env ~/hemi/popmd.env.backup
        sudo systemctl stop hemi.service
        
        curl -L -O "https://github.com/hemilabs/heminetwork/releases/download/v${latest_version}/heminetwork_v${latest_version}_linux_amd64.tar.gz"
        rm -rf hemi/*
        tar --strip-components=1 -xzvf heminetwork_v${latest_version}_linux_amd64.tar.gz -C hemi
        rm heminetwork_v${latest_version}_linux_amd64.tar.gz
        
        mv ~/hemi/popmd.env.backup ~/hemi/popmd.env
        sudo systemctl start hemi.service
        echo -e "${GREEN}Auto-update complete${NC}"
    fi
}

if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi
sleep 1

echo -e "${YELLOW}Select action:${NC}"
echo -e "${CYAN}1) Install node${NC}"
echo -e "${CYAN}2) Update node${NC}"
echo -e "${CYAN}3) Change fee${NC}"
echo -e "${CYAN}4) Remove node${NC}"
echo -e "${CYAN}5) Check logs (exit logs with CTRL+C)${NC}"

echo -e "${YELLOW}Enter number:${NC} "
read choice

case $choice in
    1)
        echo -e "${BLUE}Installing Hemi node...${NC}"
        sudo apt update && sudo apt upgrade -y
        sleep 1

        if ! command -v tar &> /dev/null; then
            sudo apt install tar -y
        fi

        echo -e "${BLUE}Downloading Hemi binary...${NC}"
        curl -L -O https://github.com/hemilabs/heminetwork/releases/download/v0.7.0/heminetwork_v0.7.0_linux_amd64.tar.gz

        mkdir -p hemi
        tar --strip-components=1 -xzvf heminetwork_v0.7.0_linux_amd64.tar.gz -C hemi
        cd hemi

        ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json

        echo -e "${RED}Save this data in a secure place:${NC}"
        cat ~/popm-address.json
        echo -e "${PURPLE}Your pubkey_hash is your tBTC address to request test tokens in Discord project.${NC}"

        echo -e "${YELLOW}Enter your wallet private key:${NC} "
        read PRIV_KEY
        echo -e "${YELLOW}Enter desired fee amount (minimum 50):${NC} "
        read FEE

        echo "POPM_BTC_PRIVKEY=$PRIV_KEY" > popmd.env
        echo "POPM_STATIC_FEE=$FEE" >> popmd.env
        echo "POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public" >> popmd.env
        sleep 1

        USERNAME=$(whoami)

        if [ "$USERNAME" == "root" ]; then
            HOME_DIR="/root"
        else
            HOME_DIR="/home/$USERNAME"
        fi

        cat <<EOT | sudo tee /etc/systemd/system/hemi.service > /dev/null
[Unit]
Description=PopMD Service
After=network.target

[Service]
User=$USERNAME
EnvironmentFile=$HOME_DIR/hemi/popmd.env
ExecStart=$HOME_DIR/hemi/popmd
WorkingDirectory=$HOME_DIR/hemi/
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT

        sudo systemctl daemon-reload
        sudo systemctl enable hemi
        sleep 1
        sudo systemctl start hemi

        echo -e "${BLUE}Setting up auto-update...${NC}"
        cat > /root/auto_update.sh <<EOL
#!/bin/bash
cd /root && ./hemi.sh auto_update
EOL
        chmod +x /root/auto_update.sh
        (crontab -l 2>/dev/null; echo "0 1 * * * /root/auto_update.sh") | crontab -

        echo -e "${GREEN}Installation complete and node started!${NC}"
        echo -e "${GREEN}Auto-update scheduled for daily checks${NC}"

        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        echo -e "${YELLOW}Command to check logs:${NC}" 
        echo "sudo journalctl -u hemi -f"
        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        ;;
    2)
        echo -e "${BLUE}Updating Hemi node...${NC}"
        
        SESSION_IDS=$(screen -ls | grep "hemi" | awk '{print $1}' | cut -d '.' -f 1)

        if [ -n "$SESSION_IDS" ]; then
            echo -e "${BLUE}Terminating screen sessions with IDs: $SESSION_IDS${NC}"
            for SESSION_ID in $SESSION_IDS; do
                screen -S "$SESSION_ID" -X quit
            done
        else
            echo -e "${BLUE}No screen sessions for Hemi node found, starting update${NC}"
        fi

        if systemctl list-units --type=service | grep -q "hemi.service"; then
            sudo systemctl stop hemi.service
            sudo systemctl disable hemi.service
            sudo rm /etc/systemd/system/hemi.service
            sudo systemctl daemon-reload
        else
            echo -e "${BLUE}Service hemi.service not found, continuing update.${NC}"
        fi
        sleep 1

        echo -e "${BLUE}Removing old node files...${NC}"
        rm -rf hemi/
        rm -f heminetwork_*.tar.gz
        
        sudo apt update && sudo apt upgrade -y

        echo -e "${BLUE}Downloading Hemi binary...${NC}"
        curl -L -O https://github.com/hemilabs/heminetwork/releases/download/v0.7.0/heminetwork_v0.7.0_linux_amd64.tar.gz

        mkdir -p hemi
        tar --strip-components=1 -xzvf heminetwork_v0.7.0_linux_amd64.tar.gz -C hemi
        cd hemi

        echo -e "${YELLOW}Enter your wallet private key:${NC} "
        read PRIV_KEY
        echo -e "${YELLOW}Enter desired fee amount (minimum 50):${NC} "
        read FEE

        echo "POPM_BTC_PRIVKEY=$PRIV_KEY" > popmd.env
        echo "POPM_STATIC_FEE=$FEE" >> popmd.env
        echo "POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public" >> popmd.env
        sleep 1

        USERNAME=$(whoami)

        if [ "$USERNAME" == "root" ]; then
            HOME_DIR="/root"
        else
            HOME_DIR="/home/$USERNAME"
        fi

        cat <<EOT | sudo tee /etc/systemd/system/hemi.service > /dev/null
[Unit]
Description=PopMD Service
After=network.target

[Service]
User=$USERNAME
EnvironmentFile=$HOME_DIR/hemi/popmd.env
ExecStart=$HOME_DIR/hemi/popmd
WorkingDirectory=$HOME_DIR/hemi/
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT

        sudo systemctl daemon-reload
        sudo systemctl enable hemi
        sleep 1
        sudo systemctl start hemi

        echo -e "${GREEN}Node updated and started!${NC}"

        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        echo -e "${YELLOW}Command to check logs:${NC}" 
        echo "sudo journalctl -u hemi -f"
        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        ;;
    3)
        echo -e "${YELLOW}Enter new fee amount (minimum 50):${NC}"
        read NEW_FEE

        if [ "$NEW_FEE" -ge 50 ]; then
            sed -i "s/^POPM_STATIC_FEE=.*/POPM_STATIC_FEE=$NEW_FEE/" $HOME/hemi/popmd.env
            sleep 1

            sudo systemctl restart hemi

            echo -e "${GREEN}Fee amount successfully changed!${NC}"

            echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
            echo -e "${YELLOW}Command to check logs:${NC}" 
            echo "sudo journalctl -u hemi -f"
            echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        else
            echo -e "${RED}Error: fee must be >= 50!${NC}"
        fi
        ;;

    4)
        echo -e "${BLUE}Removing Hemi node...${NC}"

        echo -e "${BLUE}Removing auto-update...${NC}"
        crontab -l | grep -v "auto_update.sh" | crontab -
        rm -f /root/auto_update.sh

        sudo systemctl stop hemi.service
        sudo systemctl disable hemi.service
        sudo rm /etc/systemd/system/hemi.service
        sudo systemctl daemon-reload
        sleep 1

        echo -e "${BLUE}Removing node files...${NC}"
        rm -rf hemi/
        rm -f heminetwork_*.tar.gz
        
        echo -e "${GREEN}Hemi node successfully removed!${NC}"

        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        echo -e "${YELLOW}Command to check logs:${NC}" 
        echo "sudo journalctl -u hemi -f"
        echo -e "${PURPLE}-----------------------------------------------------------------------${NC}"
        ;;
    5)
        sudo journalctl -u hemi -f
        ;;
esac
