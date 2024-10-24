echo
show "Do you have a wallet for PoP mining?"
read -p "Answer yes/no: " wallet_exists
echo

if [[ "$wallet_exists" =~ ^[Yy]es$ ]]; then
    show "Enter your private key:"
    read -p "Private key: " priv_key
    read -p "Enter a static fee (digits only, recommended: 100-200): " static_fee
elif [[ "$wallet_exists" =~ ^[Nn]o$ ]]; then
    show "Creating a new wallet..."
    ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json
    if [ $? -ne 0 ]; then
        show "Failed to create wallet."
        exit 1
    fi
    cat ~/popm-address.json
    echo
    read -p "Have you saved the above details? (y/N): " saved
    echo
    if [[ "$saved" =~ ^[Yy]$ ]]; then
        pubkey_hash=$(jq -r '.pubkey_hash' ~/popm-address.json)
        show "Join: https://discord.gg/hemixyz"
        show "Request funds at this address in the faucet channel: $pubkey_hash"
        echo
        read -p "Have you requested funds? (y/N): " faucet_requested
        if [[ "$faucet_requested" =~ ^[Yy]$ ]]; then
            priv_key=$(jq -r '.private_key' ~/popm-address.json)
            read -p "Enter a static fee (digits only, recommended: 100-200): " static_fee
            echo
        fi
    fi
else
    show "Invalid response. Please answer yes or no."
    exit 1
fi
