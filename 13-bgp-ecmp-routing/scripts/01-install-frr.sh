#!/bin/bash
# FRRouting 설치 — 전체 VM에서 실행
set -e

echo "=== FRRouting 설치 ==="

# FRR 공식 저장소 추가
curl -s https://deb.frrouting.org/frr/keys.gpg | sudo tee /usr/share/keyrings/frrouting.gpg > /dev/null
FRRVER="frr-stable"
echo "deb [signed-by=/usr/share/keyrings/frrouting.gpg] https://deb.frrouting.org/frr $(lsb_release -s -c) $FRRVER" | \
    sudo tee /etc/apt/sources.list.d/frr.list

sudo apt-get update -q
sudo apt-get install -y frr frr-pythontools

echo ""
echo "=== BGP 데몬 활성화 ==="
sudo sed -i 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons
sudo systemctl restart frr
sudo systemctl enable frr

echo ""
echo "=== FRR 상태 ==="
sudo systemctl status frr --no-pager | head -5
echo ""
echo "설치 완료. vtysh 로 설정 진입 가능."
