#!/bin/bash
# pod-vm1 → pod-vm2 pod 간 ping 테스트
# VXLAN 캡슐화를 tcpdump로 동시에 관찰한다.
# VM1에서 실행
set -e

echo "=== pod-vm1(10.244.0.2) → pod-vm2(10.244.1.2) pod 간 ping ==="
echo ""

sudo tcpdump -i ens4 -n -v port 4789 -l 2>/dev/null &
TCPDUMP_PID=$!
sleep 1

sudo ip netns exec pod-vm1 ping -c3 10.244.1.2

sleep 1
kill "$TCPDUMP_PID"
wait "$TCPDUMP_PID" 2>/dev/null || true

echo ""
echo "포인트:"
echo "  - 외부 패킷: 10.178.0.2 → 10.178.0.3  (물리 IP)"
echo "  - 내부 패킷: 10.244.0.2 → 10.244.1.2  (pod IP)"
echo "  - TTL=62: pod→host(−1)→host→pod(−1) = 2 라우팅 홉"
