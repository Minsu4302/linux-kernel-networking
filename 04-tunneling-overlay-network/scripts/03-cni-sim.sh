#!/bin/bash
# K8s Flannel VXLAN 모드를 흉내낸 pod 네임스페이스 + 오버레이 라우팅 구성
#
# 토폴로지:
#   VM1: pod-vm1 (10.244.0.2) ← veth0-host → vxlan0(192.168.100.1) ─┐
#                                                                      VXLAN tunnel
#   VM2: pod-vm2 (10.244.1.2) ← veth0-host → vxlan0(192.168.100.2) ─┘
#
# 사용법:
#   VM1에서: sudo bash 03-cni-sim.sh vm1
#   VM2에서: sudo bash 03-cni-sim.sh vm2
set -e

case "$1" in
  vm1)
    NS="pod-vm1"
    VETH_HOST_IP="10.244.0.1/24"
    VETH_POD_IP="10.244.0.2/24"
    GATEWAY="10.244.0.1"
    REMOTE_POD_SUBNET="10.244.1.0/24"
    REMOTE_VXLAN_IP="192.168.100.2"
    ;;
  vm2)
    NS="pod-vm2"
    VETH_HOST_IP="10.244.1.1/24"
    VETH_POD_IP="10.244.1.2/24"
    GATEWAY="10.244.1.1"
    REMOTE_POD_SUBNET="10.244.0.0/24"
    REMOTE_VXLAN_IP="192.168.100.1"
    ;;
  *)
    echo "사용법: $0 vm1|vm2" >&2
    exit 1
    ;;
esac

echo "=== CNI 시뮬레이션 설정 ($1) ==="

# Pod 네임스페이스 생성
ip netns add "$NS" 2>/dev/null || true

# veth pair 생성 및 배치
ip link add veth0 type veth peer name veth0-host 2>/dev/null || true
ip link set veth0 netns "$NS"
ip addr add "$VETH_HOST_IP" dev veth0-host 2>/dev/null || true
ip netns exec "$NS" ip addr add "$VETH_POD_IP" dev veth0
ip link set veth0-host up
ip netns exec "$NS" ip link set veth0 up
ip netns exec "$NS" ip link set lo up

# Pod 기본 라우트
ip netns exec "$NS" ip route add default via "$GATEWAY" 2>/dev/null || true

# 다른 VM의 pod 서브넷을 VXLAN으로 라우팅
ip route add "$REMOTE_POD_SUBNET" via "$REMOTE_VXLAN_IP" dev vxlan0 2>/dev/null || true

# IP 포워딩 활성화
sysctl -w net.ipv4.ip_forward=1 >/dev/null

echo ""
echo "--- 네임스페이스 내 IP ---"
ip netns exec "$NS" ip addr show veth0 | grep "inet "

echo ""
echo "--- 라우팅 테이블 (호스트) ---"
ip route show | grep -E "10\.244\.|vxlan0"

echo ""
echo "설정 완료. 반대편 VM에서도 같은 스크립트를 실행하세요."
