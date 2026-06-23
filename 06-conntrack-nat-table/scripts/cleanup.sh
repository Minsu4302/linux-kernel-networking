#!/bin/bash
# 실험 환경을 정리하고 sysctl을 기본값으로 복원한다.
# lab-vm-01에서 실행
set -e

echo "=== conntrack 실습 정리 ==="

echo "[1] HTTP 서버 프로세스 종료"
sudo pkill -f "python3 -m http.server 8888" 2>/dev/null && echo "  종료 완료" || echo "  이미 종료됨"

echo "[2] iptables nat 규칙 제거"
sudo iptables -t nat -D PREROUTING  -i veth-host -p tcp --dport 7777 -j REDIRECT --to-port 8888 2>/dev/null && echo "  PREROUTING REDIRECT 삭제" || true
sudo iptables -t nat -D POSTROUTING -s 10.99.0.0/24 -o veth-host -j MASQUERADE 2>/dev/null && echo "  POSTROUTING MASQUERADE 삭제" || true

echo "[3] veth pair 및 네임스페이스 삭제"
sudo ip link del veth-host 2>/dev/null && echo "  veth-host 삭제 (veth-ns 자동 삭제)" || echo "  이미 삭제됨"
sudo ip netns del test-ns  2>/dev/null && echo "  test-ns 삭제" || echo "  이미 삭제됨"

echo "[4] sysctl 기본값 복원"
sudo sysctl -w net.netfilter.nf_conntrack_max=262144               >/dev/null
sudo sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=432000 >/dev/null
sudo sysctl -w net.netfilter.nf_conntrack_tcp_timeout_time_wait=120     >/dev/null
echo "  nf_conntrack_max = 262144"
echo "  timeout_established = 432000 (기본값)"
echo "  timeout_time_wait   = 120    (기본값)"

echo ""
echo "=== 정리 완료 ==="
sudo conntrack -C && echo "현재 conntrack 엔트리 수"
