#!/bin/bash
# 두 VM 동시 폴링 — lab-vm-01에서 실행
# Primary(vm-02)가 서빙 중이면 OK, Backup(vm-03)이 서빙 시작하면 Failover 감지
PRIMARY="10.178.0.3"
BACKUP="10.178.0.4"
PORT=8080
INTERVAL=0.3

echo "================================================================"
echo "  HA Failover 모니터링"
echo "  Primary: $PRIMARY:$PORT | Backup: $BACKUP:$PORT"
echo "  (Ctrl+C 로 종료)"
echo "================================================================"
echo ""

prev_primary=""
prev_backup=""

while true; do
    ts=$(date '+%H:%M:%S.%2N')

    if curl -sf --max-time 1 "http://$PRIMARY:$PORT" > /dev/null 2>&1; then
        p_status="UP  "
    else
        p_status="DOWN"
    fi

    if curl -sf --max-time 1 "http://$BACKUP:$PORT" > /dev/null 2>&1; then
        b_status="UP  "
    else
        b_status="DOWN"
    fi

    # 상태 변화 시에만 출력
    line="[$ts] Primary=$p_status  Backup=$b_status"
    if [ "$p_status" != "$prev_primary" ] || [ "$b_status" != "$prev_backup" ]; then
        if [ "$p_status" = "DOWN" ] && [ "$b_status" = "UP  " ]; then
            echo "$line  ★ FAILOVER COMPLETE"
        elif [ "$p_status" = "DOWN" ]; then
            echo "$line  ← Primary 장애 감지"
        elif [ "$p_status" = "UP  " ] && [ "$prev_primary" = "DOWN" ]; then
            echo "$line  ← Primary 복구"
        else
            echo "$line"
        fi
        prev_primary="$p_status"
        prev_backup="$b_status"
    fi

    sleep "$INTERVAL"
done
