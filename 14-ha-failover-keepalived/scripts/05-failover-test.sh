#!/bin/bash
# Failover 시간 정밀 측정 — lab-vm-01에서 실행
# 실행 후 vm-02에서 'sudo systemctl stop keepalived' 실행
PRIMARY="10.178.0.3"
BACKUP="10.178.0.4"
PORT=8080

echo "================================================================"
echo "  Failover 시간 정밀 측정"
echo "================================================================"
echo ""
echo "현재 상태 확인:"
curl -sf --max-time 1 "http://$PRIMARY:$PORT" > /dev/null && echo "  Primary: UP" || echo "  Primary: DOWN"
curl -sf --max-time 1 "http://$BACKUP:$PORT" > /dev/null && echo "  Backup: UP" || echo "  Backup: DOWN"
echo ""
echo "→ 지금 vm-02에서 'sudo systemctl stop keepalived' 를 실행하세요."
echo "  Primary 장애를 감지하면 타이머를 시작합니다."
echo ""

# Primary 정상 응답 확인 후 대기
while ! curl -sf --max-time 0.5 "http://$PRIMARY:$PORT" > /dev/null 2>&1; do
    echo "  Primary 아직 DOWN 상태. 먼저 Primary를 시작하세요."
    sleep 2
done
echo "  Primary 정상 확인. 대기 중..."

START_MS=""
FAILOVER_MS=""

while true; do
    NOW_NS=$(date +%s%N)

    if ! curl -sf --max-time 0.3 "http://$PRIMARY:$PORT" > /dev/null 2>&1; then
        if [ -z "$START_MS" ]; then
            START_MS=$NOW_NS
            echo "[$(date '+%H:%M:%S.%3N')] Primary 장애 감지 — 타이머 시작"
        fi
    fi

    if [ -n "$START_MS" ]; then
        if curl -sf --max-time 0.3 "http://$BACKUP:$PORT" > /dev/null 2>&1; then
            END_MS=$(date +%s%N)
            ELAPSED=$(( (END_MS - START_MS) / 1000000 ))
            echo "[$(date '+%H:%M:%S.%3N')] Backup 서비스 응답 확인"
            echo ""
            echo "================================================================"
            echo "  Failover 완료 시간: ${ELAPSED} ms"
            echo "================================================================"
            FAILOVER_MS=$ELAPSED
            break
        fi
    fi

    sleep 0.1
done

echo ""
echo "Backup 응답 내용:"
curl -s --max-time 2 "http://$BACKUP:$PORT" | grep -o '<h1>.*</h1>'
