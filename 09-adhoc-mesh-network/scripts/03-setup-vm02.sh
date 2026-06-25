#!/bin/bash
# WireGuard 설정 — lab-vm-02 (WireGuard IP: 10.0.0.2/24)
# 사전 조건: 다른 두 노드의 공개키를 실행 전에 변수에 채워야 함
#
# 물리 IP 구성:
#   lab-vm-01: 10.178.0.2
#   lab-vm-02: 10.178.0.3  (이 스크립트를 실행하는 노드)
#   lab-vm-03: 10.178.0.4
set -e

PUBKEY_VM01="/1uVkAmP5nWT9nDTa5aLD2x7Z6HJT9G8v61xScxRnDA="
PUBKEY_VM03="Y/M+IFgqVA4e5pmLscOm9dBEBg2zYSRr47TR+8JBOXc="

PRIVATE_KEY=$(sudo cat /etc/wireguard/privatekey)

echo "=== lab-vm-02 WireGuard 설정 생성 ==="
sudo tee /etc/wireguard/wg0.conf > /dev/null << EOF
[Interface]
Address    = 10.0.0.2/24
ListenPort = 51820
PrivateKey = ${PRIVATE_KEY}

# lab-vm-01
[Peer]
PublicKey  = ${PUBKEY_VM01}
AllowedIPs = 10.0.0.1/32
Endpoint   = 10.178.0.2:51820

# lab-vm-03
[Peer]
PublicKey  = ${PUBKEY_VM03}
AllowedIPs = 10.0.0.3/32
Endpoint   = 10.178.0.4:51820
EOF

sudo chmod 600 /etc/wireguard/wg0.conf
echo "  /etc/wireguard/wg0.conf 작성 완료"
echo ""

echo "=== WireGuard 인터페이스 시작 ==="
sudo wg-quick up wg0

echo ""
echo "=== 상태 확인 ==="
sudo wg show wg0
