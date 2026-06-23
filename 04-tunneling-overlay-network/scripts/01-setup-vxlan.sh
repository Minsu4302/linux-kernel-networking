#!/bin/bash
# 두 VM 간 VXLAN 터널을 설정한다.
# VM1(10.178.0.2): VXLAN IP 192.168.100.1
# VM2(10.178.0.3): VXLAN IP 192.168.100.2
#
# 사용법:
#   VM1에서: sudo bash 01-setup-vxlan.sh vm1
#   VM2에서: sudo bash 01-setup-vxlan.sh vm2
set -e

VM1_PHY="10.178.0.2"
VM2_PHY="10.178.0.3"
VNI=100
DSTPORT=4789

case "$1" in
  vm1)
    REMOTE="$VM2_PHY"
    LOCAL_VXLAN_IP="192.168.100.1/24"
    ;;
  vm2)
    REMOTE="$VM1_PHY"
    LOCAL_VXLAN_IP="192.168.100.2/24"
    ;;
  *)
    echo "사용법: $0 vm1|vm2" >&2
    exit 1
    ;;
esac

echo "=== VXLAN 인터페이스 설정 ($1) ==="
ip link add vxlan0 type vxlan id "$VNI" remote "$REMOTE" dstport "$DSTPORT" dev ens4 2>/dev/null || true
ip addr add "$LOCAL_VXLAN_IP" dev vxlan0 2>/dev/null || true
ip link set vxlan0 up

echo ""
echo "--- vxlan0 상태 ---"
ip addr show vxlan0
echo ""
echo "--- MTU 확인 (VXLAN 오버헤드 50바이트 차감) ---"
ip link show vxlan0 | grep -o "mtu [0-9]*"
