#!/bin/bash
# NAT(DNAT/REDIRECT) 적용 시 conntrack이 포트 변환을 기록하는 방식을 관찰한다.
# lab-vm-01에서 실행
set -e

echo "=== NAT 추적 데모 (REDIRECT: 7777 → 8888) ==="
echo ""

# 환경 구성
echo "[1] 네트워크 네임스페이스 + veth pair 생성"
sudo ip netns add test-ns 2>/dev/null || true
sudo ip link add veth-host type veth peer name veth-ns 2>/dev/null || true
sudo ip link set veth-ns netns test-ns
sudo ip addr add 10.99.0.1/24 dev veth-host 2>/dev/null || true
sudo ip netns exec test-ns ip addr add 10.99.0.2/24 dev veth-ns 2>/dev/null || true
sudo ip link set veth-host up
sudo ip netns exec test-ns ip link set veth-ns up
echo "  veth-host: 10.99.0.1  ↔  veth-ns: 10.99.0.2 (test-ns)"
echo ""

echo "[2] REDIRECT 규칙 추가: 7777 → 8888"
sudo iptables -t nat -A PREROUTING -i veth-host -p tcp --dport 7777 -j REDIRECT --to-port 8888
echo ""

echo "[3] HTTP 서버 실행 (포트 8888)"
python3 -m http.server 8888 &>/dev/null &
HTTP_PID=$!
sleep 1
echo "  PID=$HTTP_PID"
echo ""

echo "[4] 네임스페이스에서 7777로 연결"
sudo ip netns exec test-ns curl -s http://10.99.0.1:7777 > /dev/null
echo ""

echo "[5] conntrack에서 NAT 엔트리 확인"
sudo conntrack -L 2>/dev/null | grep 7777
echo ""

echo "포인트:"
echo "  Original: dport=7777   (클라이언트가 연결한 포트)"
echo "  Reply:    sport=8888   (실제 응답한 포트, DNAT 변환 기록)"
echo "  conntrack이 이 매핑을 유지하기 때문에 응답 패킷이 클라이언트에게"
echo "  7777에서 온 것처럼 돌아올 수 있음 → stateful NAT의 핵심"

# 정리
kill "$HTTP_PID" 2>/dev/null || true
sudo iptables -t nat -D PREROUTING -i veth-host -p tcp --dport 7777 -j REDIRECT --to-port 8888 2>/dev/null || true
sudo ip link del veth-host 2>/dev/null || true
sudo ip netns del test-ns 2>/dev/null || true
