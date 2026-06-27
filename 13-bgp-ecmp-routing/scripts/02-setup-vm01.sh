#!/bin/bash
# BGP 설정 — lab-vm-01 (AS 65001, 클라이언트/측정 노드)
# 실행 전 VM IP 확인: ip addr show ens4
set -e

VM02_IP="${1:-10.178.0.3}"   # lab-vm-02 물리 IP
VM03_IP="${2:-10.178.0.4}"   # lab-vm-03 물리 IP

echo "=== vm-01 BGP 설정 (AS 65001) ==="
echo "  피어 vm-02: $VM02_IP (AS 65002)"
echo "  피어 vm-03: $VM03_IP (AS 65003)"

# ECMP 활성화 (커널 레벨)
sudo sysctl -w net.ipv4.fib_multipath_hash_policy=1   # L4 해시 (5-tuple)
sudo sysctl -w net.ipv4.fib_multipath_use_neigh=1

# FRR vtysh 설정 주입
sudo vtysh -c "
configure terminal
  router bgp 65001
    bgp router-id 10.178.0.2
    bgp bestpath as-path multipath-relax
    maximum-paths 4
    neighbor $VM02_IP remote-as 65002
    neighbor $VM02_IP timers 3 9
    neighbor $VM03_IP remote-as 65003
    neighbor $VM03_IP timers 3 9
  exit
  ip route 0.0.0.0/0 Null0
exit
write memory
"

echo ""
echo "=== 설정 완료. BGP 피어 대기 중... ==="
echo "  확인: sudo vtysh -c 'show bgp summary'"
