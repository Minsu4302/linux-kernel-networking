#!/bin/bash
# ICMP Flood 공격 시뮬레이션 — lab-vm-01(공격자 노드)에서 실행
# 사용법: ./05-attacker-flood.sh [duration_sec]
set -e

TARGET="10.178.0.3"
DURATION=${1:-15}

echo "=== ICMP Flood 시뮬레이션 ==="
echo "  대상: $TARGET"
echo "  시간: ${DURATION}초"
echo "  (lab-vm-02에서 측정 스크립트가 실행 중이어야 합니다)"
echo ""

sudo timeout "$DURATION" hping3 --flood -1 "$TARGET" 2>&1 | tail -5 || true

echo ""
echo "=== Flood 종료 ==="
