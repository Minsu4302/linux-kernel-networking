#!/bin/bash
# BGP 설정 — lab-vm-01 (AS 65001, 클라이언트/측정 노드)
# GCP 환경: IP가 /32 unnumbered로 할당됨 → ebgp-multihop + disable-connected-check 필요
set -e

VM02_IP="${1:-10.178.0.3}"   # lab-vm-02 물리 IP
VM03_IP="${2:-10.178.0.4}"   # lab-vm-03 물리 IP
GW="${3:-10.178.0.1}"         # GCP 서브넷 게이트웨이

echo "=== vm-01 BGP 설정 (AS 65001) ==="
echo "  피어 vm-02: $VM02_IP (AS 65002)"
echo "  피어 vm-03: $VM03_IP (AS 65003)"

# ECMP 활성화 (커널 레벨)
sudo sysctl -w net.ipv4.fib_multipath_hash_policy=1
sudo sysctl -w net.ipv4.fib_multipath_use_neigh=1

# FRR 피어 경로를 zebra에 등록 (GCP /32 환경: 게이트웨이 경유)
sudo vtysh -c "
configure terminal
  ip route ${VM02_IP}/32 $GW
  ip route ${VM03_IP}/32 $GW
  router bgp 65001
    bgp router-id 10.178.0.2
    bgp bestpath as-path multipath-relax
    no bgp ebgp-requires-policy
    neighbor $VM02_IP remote-as 65002
    neighbor $VM02_IP timers 3 9
    neighbor $VM02_IP ebgp-multihop 2
    neighbor $VM02_IP disable-connected-check
    neighbor $VM03_IP remote-as 65003
    neighbor $VM03_IP timers 3 9
    neighbor $VM03_IP ebgp-multihop 2
    neighbor $VM03_IP disable-connected-check
    address-family ipv4 unicast
      maximum-paths 4
    exit-address-family
  exit
exit
write memory
"

echo ""
echo "=== 설정 완료. BGP 피어 대기 중... ==="
echo "  확인: sudo vtysh -c 'show bgp summary'"
