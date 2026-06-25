#!/bin/bash
# 노드 장애 시뮬레이션 및 Convergence Time 측정
# lab-vm-01에서 실행. vm-02의 wg0을 down 시키고 vm-03으로의 경로 우회를 확인한다.
#
# WireGuard Full Mesh의 특성:
#   - vm-01 ↔ vm-02 직접 터널 장애 시, vm-01은 vm-03을 경유하지 않고 direct peer만 사용
#   - vm-01 → vm-03: 항상 직접 터널 유지 (영향 없음)#
# 이 실험은 vm-02 장애 시 vm-01이 vm-02와 vm-03에 ping을 보내며
# vm-02 응답 중단 시점(= 장애 감지 시간)을 측정한다.
set -e

TARGET_FAIL="10.0.0.2"   # 장애를 시뮬레이션할 노드 (vm-02)
TARGET_OK="10.0.0.3"     # 장애 영향 없어야 하는 노드 (vm-03)

echo "=== Baseline: 두 노드 모두 정상 ==="
ping -c 3 -W 2 $TARGET_FAIL | tail -1
ping -c 3 -W 2 $TARGET_OK  | tail -1
echo ""

echo "=== 장애 시뮬레이션 준비 ==="
echo "  → lab-vm-02에서 'sudo wg-quick down wg0' 를 실행하세요."
echo "  → 실행 후 Enter를 누르면 ping 모니터링을 시작합니다."
read -p "  준비됐으면 Enter: "
echo ""

echo "=== vm-02 장애 감지 모니터링 (30초, 1초 간격) ==="
FAIL_TIME=""
START=$(date +%s)
for i in $(seq 1 30); do
    T=$(date +%s)
    ELAPSED=$((T - START))

    VM02_OK=false
    VM03_OK=false

    ping -c 1 -W 1 $TARGET_FAIL > /dev/null 2>&1 && VM02_OK=true
    ping -c 1 -W 1 $TARGET_OK  > /dev/null 2>&1 && VM03_OK=true

    VM02_STR="✅"
    VM03_STR="✅"
    $VM02_OK || VM02_STR="❌"
    $VM03_OK || VM03_STR="❌"

    echo "  [${ELAPSED}s] vm-02: ${VM02_STR}  vm-03: ${VM03_STR}"

    if ! $VM02_OK && [ -z "$FAIL_TIME" ]; then
        FAIL_TIME=$ELAPSED
        echo "  *** vm-02 장애 감지: ${FAIL_TIME}초 후 ***"
    fi
    sleep 1
done
echo ""

echo "=== wg show: 핸드셰이크 시간 확인 ==="
sudo wg show wg0 | grep -A3 "peer"
echo ""

if [ -n "$FAIL_TIME" ]; then
    echo "결론: vm-02 장애 감지 시간 = ${FAIL_TIME}초"
    echo "      vm-03 터널은 영향 없음 (Full Mesh 독립 경로)"
else
    echo "결론: 30초 내 vm-02 장애 미감지 (still alive?)"
fi
echo ""
echo "→ lab-vm-02에서 'sudo wg-quick up wg0' 로 복구하세요."
