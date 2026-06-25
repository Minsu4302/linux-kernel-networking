#!/bin/bash
# WireGuard 설치 및 키 쌍 생성
# 3대 모두 동일하게 실행: lab-vm-01, lab-vm-02, lab-vm-03
set -e

echo "=== WireGuard 설치 ==="
sudo apt-get update -qq
sudo apt-get install -y wireguard wireguard-tools

echo ""
echo "=== 키 쌍 생성 ==="
cd /etc/wireguard
umask 077
wg genkey | sudo tee /etc/wireguard/privatekey | wg pubkey | sudo tee /etc/wireguard/pubkey
echo ""
echo "  Private key: $(sudo cat /etc/wireguard/privatekey)"
echo "  Public  key: $(sudo cat /etc/wireguard/pubkey)"
echo ""
echo "  ↑ 이 공개키를 다른 노드의 [Peer] 섹션에 등록해야 합니다."
