#!/bin/bash
# K8s Pod 시뮬레이션: network namespace + Linux bridge + veth pair 구성
#
# 실행 결과:
#   br0 (10.200.0.1/24) — K8s의 cbr0/cni0 역할
#   ├── veth-a-host ↔ pod-a namespace (10.200.0.10) — python3 http.server :8080
#   ├── veth-b-host ↔ pod-b namespace (10.200.0.11) — python3 http.server :8080
#   └── veth-c-host ↔ pod-c namespace (10.200.0.12) — python3 http.server :8080
#
# 환경: Ubuntu 22.04, GCP VM (ens4 인터페이스, 커널 6.8.0-1060-gcp)
# 필요 패키지: iproute2(기본 포함), python3(기본 포함)
# root 권한 필요: sudo로 실행

set -e

echo "=== 커널 모듈 로드 ==="
modprobe ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh xt_statistic nf_conntrack 2>/dev/null || true
lsmod | grep -E 'ip_vs|xt_statistic' | awk '{print $1}' | tr '\n' ' '
echo ""

echo "=== Linux bridge 생성 ==="
ip link add br0 type bridge 2>/dev/null || echo "(br0 이미 존재)"
ip addr add 10.200.0.1/24 dev br0 2>/dev/null || true
ip link set br0 up

echo "=== network namespace 3개 생성 ==="
for ns in pod-a pod-b pod-c; do
    ip netns add $ns 2>/dev/null || echo "($ns 이미 존재)"
done
ip netns list

echo "=== veth pair 생성 및 연결 ==="
for pod in a b c; do
    ip link add veth-${pod}-host type veth peer name veth-${pod}-pod 2>/dev/null || true
    ip link set veth-${pod}-host master br0
    ip link set veth-${pod}-host up
    ip link set veth-${pod}-pod netns pod-${pod}
done

echo "=== 각 namespace IP/라우팅 설정 ==="
ip netns exec pod-a ip addr add 10.200.0.10/24 dev veth-a-pod 2>/dev/null || true
ip netns exec pod-a ip link set veth-a-pod up
ip netns exec pod-a ip link set lo up
ip netns exec pod-a ip route add default via 10.200.0.1 2>/dev/null || true

ip netns exec pod-b ip addr add 10.200.0.11/24 dev veth-b-pod 2>/dev/null || true
ip netns exec pod-b ip link set veth-b-pod up
ip netns exec pod-b ip link set lo up
ip netns exec pod-b ip route add default via 10.200.0.1 2>/dev/null || true

ip netns exec pod-c ip addr add 10.200.0.12/24 dev veth-c-pod 2>/dev/null || true
ip netns exec pod-c ip link set veth-c-pod up
ip netns exec pod-c ip link set lo up
ip netns exec pod-c ip route add default via 10.200.0.1 2>/dev/null || true

echo "=== IP 포워딩 및 route_localnet 활성화 ==="
# route_localnet=1: 127.0.0.0/8 패킷을 non-loopback 인터페이스로 라우팅 허용
# (NodePort 127.0.0.1:30080 → pod DNAT 시 필요. 없으면 martian source로 드롭)
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.route_localnet=1
sysctl -w net.ipv4.conf.br0.route_localnet=1

echo "=== HTTP 서버 시작 (각 namespace) ==="
mkdir -p /tmp/pod-a /tmp/pod-b /tmp/pod-c
echo "Hello from pod-a (10.200.0.10)" > /tmp/pod-a/index.html
echo "Hello from pod-b (10.200.0.11)" > /tmp/pod-b/index.html
echo "Hello from pod-c (10.200.0.12)" > /tmp/pod-c/index.html

# 기존 서버 프로세스 정리
pkill -f "python3 -m http.server 8080" 2>/dev/null || true
sleep 1

ip netns exec pod-a bash -c "cd /tmp/pod-a && python3 -m http.server 8080 > /tmp/pod-a.log 2>&1" &
ip netns exec pod-b bash -c "cd /tmp/pod-b && python3 -m http.server 8080 > /tmp/pod-b.log 2>&1" &
ip netns exec pod-c bash -c "cd /tmp/pod-c && python3 -m http.server 8080 > /tmp/pod-c.log 2>&1" &
sleep 1

echo ""
echo "=== 직접 접근 검증 ==="
curl -s http://10.200.0.10:8080/ || echo "FAIL: pod-a"
curl -s http://10.200.0.11:8080/ || echo "FAIL: pod-b"
curl -s http://10.200.0.12:8080/ || echo "FAIL: pod-c"
echo "setup 완료"
