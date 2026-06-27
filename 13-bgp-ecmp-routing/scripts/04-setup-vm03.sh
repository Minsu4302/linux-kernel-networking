#!/bin/bash
# BGP 설정 — lab-vm-03 (AS 65003, 경로 광고 노드)
# GCP 환경: IP가 /32 unnumbered로 할당됨 → ebgp-multihop + disable-connected-check 필요
set -e

VM01_IP="${1:-10.178.0.2}"   # lab-vm-01 물리 IP
GW="${2:-10.178.0.1}"         # GCP 서브넷 게이트웨이
ADVERTISE_PREFIX="10.200.1.0/24"

echo "=== vm-03 BGP 설정 (AS 65003) ==="
echo "  피어 vm-01: $VM01_IP (AS 65001)"
echo "  광고 대역: $ADVERTISE_PREFIX"

# loopback에 목적지 네트워크 할당
sudo ip addr add 10.200.1.1/24 dev lo 2>/dev/null || echo "  (이미 설정됨)"

# FRR 설정
sudo vtysh -c "
configure terminal
  ip route ${VM01_IP}/32 $GW
  router bgp 65003
    bgp router-id 10.178.0.4
    no bgp ebgp-requires-policy
    neighbor $VM01_IP remote-as 65001
    neighbor $VM01_IP timers 3 9
    neighbor $VM01_IP ebgp-multihop 2
    neighbor $VM01_IP disable-connected-check
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
