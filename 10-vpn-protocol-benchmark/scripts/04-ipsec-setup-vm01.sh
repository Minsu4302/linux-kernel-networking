#!/bin/bash
# IPsec (StrongSwan IKEv2) 설정 — lab-vm-01
# 물리 IP: lab-vm-01=10.178.0.2, lab-vm-02=10.178.0.3
# GCP 사전 조건: 방화벽에서 ESP(protocol 50) 허용 필요
#   gcloud compute firewall-rules create allow-ipsec-esp \
#     --network=default --allow=esp --source-ranges=10.178.0.0/20
set -e

echo "=== IPsec 설정 생성 (lab-vm-01) ==="
sudo tee /etc/ipsec.conf > /dev/null << 'EOF'
config setup
    charondebug="ike 0, knl 0"

conn vm01-vm02
    type=transport
    left=10.178.0.2
    right=10.178.0.3
    ike=aes256gcm16-sha256-ecp256!
    esp=aes256gcm16!
    keyexchange=ikev2
    authby=psk
    auto=start
EOF

sudo tee /etc/ipsec.secrets > /dev/null << 'EOF'
10.178.0.2 10.178.0.3 : PSK "lab-ipsec-secret-2026"
EOF

sudo chmod 600 /etc/ipsec.secrets
sudo ipsec restart
sleep 5
echo ""
echo "=== IPsec SA 상태 ==="
sudo ipsec status
