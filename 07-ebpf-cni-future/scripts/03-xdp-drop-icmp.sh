#!/bin/bash
# drop_icmp XDP 프로그램으로 ICMP를 커널 스택 진입 전에 차단한다.
# lab-vm-01에서 실행. 01-build.sh를 먼저 실행해야 한다.
set -e

BUILD_DIR="$HOME/ebpf-lab"
IFACE="ens4"   # 환경에 맞게 수정
TARGET="8.8.8.8"

echo "=== drop_icmp XDP 로드 ==="
sudo ip link set dev "$IFACE" xdpgeneric obj "$BUILD_DIR/drop_icmp.o" sec xdp
echo "  로드 완료: $(ip link show "$IFACE" | grep 'prog/xdp')"
echo "  로드된 BPF 프로그램:"
sudo bpftool prog show id "$(sudo bpftool prog show | grep -B1 'drop_icmp\|xdp' | grep '^[0-9]' | tail -1 | awk '{print $1}' | tr -d ':')" 2>/dev/null || \
    sudo bpftool prog show | tail -6
echo ""

echo "=== [1] ICMP 테스트 → 드롭 예상 ==="
ping -c3 -W1 "$TARGET" || echo "ping 실패 ← XDP_DROP: ICMP reply를 커널 스택 진입 전에 드롭"
echo ""

echo "=== [2] TCP 테스트 → 정상 예상 (SSH 세션 유지) ==="
curl -s --max-time 5 http://example.com | head -c 20 && echo "...  ← TCP curl 성공 (XDP_PASS)"
echo ""

echo "=== [3] XDP 언로드 후 ping 복구 ==="
sudo ip link set dev "$IFACE" xdpgeneric off
ping -c3 "$TARGET" | tail -2
echo ""

echo "포인트:"
echo "  iptables DROP: SKB 할당 → 체인 순회 → DROP (추가 오버헤드)"
echo "  XDP DROP:      드라이버 레벨 → 즉시 XDP_DROP (SKB 할당 없음)"
echo "  → XDP는 DDoS 트래픽을 가장 낮은 비용으로 차단 가능"
echo "  → Cilium은 이 원리로 kube-proxy 없이 K8s 서비스 처리"
