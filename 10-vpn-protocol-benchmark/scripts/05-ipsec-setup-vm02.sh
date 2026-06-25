#!/bin/bash
# IPsec (StrongSwan IKEv2) 설정 — lab-vm-02
set -e

echo "=== IPsec 설정 생성 (lab-vm-02) ==="
sudo tee /etc/ipsec.conf > /dev/null << 'EOF'
config setup
    charondebug="ike 0, knl 0"

conn vm01-vm02
    type=transport
    left=10.178.0.3
    right=10.178.0.2
    ike=aes256gcm16-sha256-ecp256!
    esp=aes256gcm16!
    keyexchange=ikev2
    authby=psk
    auto=start
EOF

sudo tee /etc/ipsec.secrets > /dev/null << 'EOF'
10.178.0.3 10.178.0.2 : PSK "lab-ipsec-secret-2026"
EOF

sudo chmod 600 /etc/ipsec.secrets
sudo ipsec restart
sleep 5
echo ""
echo "=== IPsec SA 상태 ==="
sudo ipsec status
