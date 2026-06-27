#!/bin/bash
# BGP 수렴 시간 측정 — lab-vm-01에서 실행
# vm-02의 FRR을 외부에서 종료하는 것은 수동으로 수행:
#   [vm-02] sudo systemctl stop frr
# 이 스크립트는 라우팅 테이블 변화를 폴링해 수렴 시간을 기록한다.
set -e

TARGET="10.200.1.0/24"
VM02_IP="${1:-10.178.0.3}"
INTERVAL=0.2   # 200ms 간격으로 폴링

echo "================================================================"
echo "  BGP 수렴 시간 측정"
echo "================================================================"
echo "  대상 경로: $TARGET"
echo "  vm-02 next-hop: $VM02_IP"
echo ""
echo "현재 ECMP 경로:"
ip route show "$TARGET"
echo ""
echo "→ 지금 vm-02에서 'sudo systemctl stop frr' 를 실행하세요."
echo "  경로 변화를 감지하면 수렴 시간을 출력합니다."
echo "  (Ctrl+C 로 중단)"
echo ""

START_TIME=""
CONVERGED=false

while true; do
    ROUTES=$(ip route show "$TARGET" 2>/dev/null)
    HAS_VM02=$(echo "$ROUTES" | grep -c "$VM02_IP" || true)

    if [ -z "$START_TIME" ] && [ "$HAS_VM02" -eq 0 ]; then
        # vm-02 경로가 사라진 첫 순간
        START_TIME=$(date +%s%N)
        echo "[$(date '+%H:%M:%S.%3N')] vm-02 경로 소실 감지"
    fi

    if [ -n "$START_TIME" ] && [ "$HAS_VM02" -eq 0 ]; then
        # vm-03 경로만 남아있는지 확인
        REMAINING=$(echo "$ROUTES" | grep -c 'via' || true)
        if [ "$REMAINING" -ge 1 ]; then
            END_TIME=$(date +%s%N)
            ELAPSED_MS=$(( (END_TIME - START_TIME) / 1000000 ))
            echo "[$(date '+%H:%M:%S.%3N')] 수렴 완료 — vm-03 경로 유지"
            echo ""
            echo "  수렴 시간: ${ELAPSED_MS} ms"
            echo ""
            echo "수렴 후 라우팅 테이블:"
            ip route show "$TARGET"
            CONVERGED=true
            break
        fi
    fi

    sleep "$INTERVAL"
done

if [ "$CONVERGED" = true ]; then
    echo ""
    echo "================================================================"
    echo "  BGP Hold Timer 설정: 9초 (timers 3 9)"
    echo "  이론 수렴 시간: ~9초 (Hold Timer 만료 후 경로 철회)"
    echo "================================================================"
fi
