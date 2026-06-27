#!/bin/bash
# FRR BGP 설정 초기화 — 전체 VM에서 실행
set -e

echo "=== FRR 설정 초기화 ==="
sudo vtysh -c "
configure terminal
  no router bgp
exit
write memory
" 2>/dev/null || true

sudo systemctl stop frr 2>/dev/null || true
echo "  FRR 중지 완료"

echo ""
echo "=== loopback 주소 제거 ==="
sudo ip addr del 10.200.1.1/24 dev lo 2>/dev/null && echo "  제거 완료" || echo "  없음"

echo ""
echo "=== 정리 완료 ==="
ip route show | grep 10.200 || echo "  10.200 경로 없음 (정상)"
