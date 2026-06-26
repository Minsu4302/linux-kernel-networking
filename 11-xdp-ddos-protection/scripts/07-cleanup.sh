#!/bin/bash
# XDP 언로드 및 iptables 정리 — lab-vm-02에서 실행
set -e

IFACE=$(ip route | awk '/default/{print $5; exit}')

echo "=== XDP 언로드 ==="
if sudo ip link show dev "$IFACE" | grep -q xdpgeneric; then
    sudo ip link set dev "$IFACE" xdpgeneric off
    echo "  xdpgeneric 언로드 완료"
else
    echo "  XDP 미로드 상태"
fi

echo ""
echo "=== iptables 잔여 규칙 확인 ==="
sudo iptables -L INPUT -n -v | grep -E "DROP|ACCEPT" || echo "  없음"

echo ""
echo "=== 정리 완료 ==="
