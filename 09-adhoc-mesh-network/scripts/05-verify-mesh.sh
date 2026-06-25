#!/bin/bash
# WireGuard Full Mesh 연결 검증
# 어느 노드에서 실행해도 동작 (자신의 IP는 ping 생략됨)
set -e

WG_VM01="10.0.0.1"
WG_VM02="10.0.0.2"
WG_VM03="10.0.0.3"

MY_IP=$(ip addr show wg0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
echo "=== WireGuard Mesh 연결 검증 (이 노드: ${MY_IP}) ==="
echo ""

echo "--- wg show wg0 ---"
sudo wg show wg0
echo ""

echo "--- Ping 테스트 ---"
for target in $WG_VM01 $WG_VM02 $WG_VM03; do
    if [ "$target" = "$MY_IP" ]; then
        echo "  $target : (자기 자신, 스킵)"
        continue
    fi
    if ping -c 2 -W 2 "$target" > /dev/null 2>&1; then
        RTT=$(ping -c 3 -W 2 "$target" | tail -1 | awk -F'/' '{print $5}')
        echo "  $target : ✅ 응답 (avg ${RTT}ms)"
    else
        echo "  $target : ❌ 응답 없음"
    fi
done
echo ""

echo "--- 라우팅 테이블 (wg0 관련) ---"
ip route show dev wg0 2>/dev/null || echo "  wg0 없음"
