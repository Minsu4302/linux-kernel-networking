#!/bin/bash
# BGP 세션 및 ECMP 라우팅 확인 — lab-vm-01에서 실행
set -e

echo "=== BGP 피어 상태 ==="
sudo vtysh -c "show bgp summary"

echo ""
echo "=== BGP 수신 경로 ==="
sudo vtysh -c "show bgp ipv4 unicast"

echo ""
echo "=== 커널 라우팅 테이블 (ECMP 확인) ==="
ip route show 10.200.1.0/24

echo ""
echo "=== ECMP next-hop 목록 ==="
ip route show 10.200.1.0/24 | grep -oP 'via \S+' | sort | uniq -c

echo ""
echo "=== ping 연결 테스트 ==="
ping -c 3 -W 1 10.200.1.1 && echo "  연결 OK" || echo "  연결 실패"
