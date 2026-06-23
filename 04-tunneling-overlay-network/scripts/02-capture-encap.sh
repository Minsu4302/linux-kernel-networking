#!/bin/bash
# ens4에서 VXLAN 패킷을 캡처해 캡슐화 구조를 관찰한다.
# 사전 조건: 01-setup-vxlan.sh 실행 후 두 VM 모두 vxlan0 UP 상태
# VM1에서 실행
set -e

echo "=== VXLAN 캡슐화 관찰 ==="
echo "ens4에서 UDP 4789 패킷 캡처 중..."
echo ""

sudo tcpdump -i ens4 -n -v port 4789 -l 2>/dev/null &
TCPDUMP_PID=$!
sleep 1

echo "--- ping 192.168.100.2 (VXLAN 터널 직접) ---"
ping -c3 192.168.100.2

sleep 1
kill "$TCPDUMP_PID"
wait "$TCPDUMP_PID" 2>/dev/null || true

echo ""
echo "읽는 법:"
echo "  외부 헤더: 10.178.0.x > 10.178.0.y  UDP:4789"
echo "  VXLAN 헤더: vni 100"
echo "  내부 페이로드: 192.168.100.x > 192.168.100.y  ICMP"
