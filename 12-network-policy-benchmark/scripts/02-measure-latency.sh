#!/bin/bash
# ping RTT 측정 — lab-vm-01(클라이언트)에서 실행
# 사용법: ./02-measure-latency.sh <label> <target_ip>
# 예시:   ./02-measure-latency.sh "iptables-1000" 10.178.0.3
set -e

LABEL=${1:-"test"}
TARGET=${2:-"10.178.0.3"}
COUNT=200   # 200회 ping → 통계 안정성 확보

echo "=== RTT 측정: ${LABEL} ==="
echo "  대상: $TARGET"
echo "  횟수: ${COUNT}회"
echo ""

RESULT=$(ping -c "$COUNT" -q "$TARGET" 2>&1)
echo "$RESULT"

# avg RTT 추출 (rtt min/avg/max/mdev 형식)
AVG=$(echo "$RESULT" | grep -oP 'rtt.*=\s*[\d.]+/\K[\d.]+')
echo ""
echo "  [$LABEL] avg RTT: ${AVG} ms"

# 결과 저장
OUTFILE="/tmp/latency_${LABEL}.txt"
echo "$AVG" > "$OUTFILE"
echo "  저장: $OUTFILE"
