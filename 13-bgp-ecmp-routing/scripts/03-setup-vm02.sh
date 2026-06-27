#!/bin/bash
# BGP 설정 — lab-vm-02 (AS 65002, 경로 광고 노드)
set -e

VM01_IP="${1:-10.178.0.2}"   # lab-vm-01 물리 IP
ADVERTISE_PREFIX="10.200.1.0/24"

echo "=== vm-02 BGP 설정 (AS 65002) ==="
echo "  피어 vm-01: $VM01_IP (AS 65001)"
echo "  광고 대역: $ADVERTISE_PREFIX"

# loopback에 목적지 네트워크 할당
sudo ip addr add 10.200.1.1/24 dev lo 2>/dev/null || echo "  (이미 설정됨)"

# FRR vtysh 설정
sudo vtysh -c "
configure terminal
  router bgp 65002
    bgp router-id 10.178.0.3
    neighbor $VM01_IP remote-as 65001
    neighbor $VM01_IP timers 3 9
    address-family ipv4 unicast
      network $ADVERTISE_PREFIX
    exit-address-family
  exit
exit
write memory
"

echo ""
echo "=== 설정 완료 ==="
echo "  확인: sudo vtysh -c 'show bgp summary'"
echo "  광고 경로: sudo vtysh -c 'show bgp ipv4 unicast'"
