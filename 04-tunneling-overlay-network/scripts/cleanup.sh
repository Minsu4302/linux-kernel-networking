#!/bin/bash
# VXLAN 인터페이스, pod 네임스페이스, 라우팅 설정을 모두 제거한다.
# VM1, VM2 양쪽 모두에서 실행
set -e

echo "=== 정리 시작 ==="

# pod 네임스페이스 삭제
for NS in pod-vm1 pod-vm2; do
    if ip netns list 2>/dev/null | grep -q "^$NS"; then
        ip netns del "$NS" 2>/dev/null && echo "  네임스페이스 $NS 삭제"
    fi
done

# veth pair (호스트 쪽 삭제하면 네임스페이스 쪽도 자동 삭제)
ip link del veth0-host 2>/dev/null && echo "  veth pair 삭제" || true

# VXLAN 인터페이스 삭제
ip link del vxlan0 2>/dev/null && echo "  vxlan0 삭제" || true

echo "=== 정리 완료 ==="
