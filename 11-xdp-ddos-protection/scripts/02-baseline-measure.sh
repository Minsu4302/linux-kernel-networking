#!/bin/bash
# Baseline CPU 측정 — lab-vm-02(방어 노드)에서 실행
# 방어 없는 상태에서 flood를 받을 때 CPU 사용률을 측정한다.
# lab-vm-01에서 05-attacker-flood.sh를 동시에 실행해야 한다.
set -e

DURATION=20
IFACE=$(ip route | awk '/default/{print $5; exit}')

echo "=== Baseline 측정 시작 ==="
echo "  인터페이스: $IFACE"
echo "  측정 시간: ${DURATION}초"
echo "  → 지금 lab-vm-01에서 05-attacker-flood.sh 를 실행하세요"
echo ""

# CPU + 네트워크 수신 패킷 수 동시 측정
mpstat 1 $DURATION > /tmp/baseline_cpu.txt &
sar -n DEV 1 $DURATION 2>/dev/null | grep "$IFACE" > /tmp/baseline_net.txt &
wait

echo "=== [Baseline] CPU 평균 ==="
awk '/Average/ {printf "  usr=%.1f%% sys=%.1f%% sirq=%.1f%% idle=%.1f%%  (사용률=%.1f%%)\n",
    $2, $4, $6, $12, 100-$12}' /tmp/baseline_cpu.txt

echo ""
echo "=== [Baseline] 수신 패킷률 (pps) ==="
awk 'NR>2 {sum+=$5; cnt++} END {if(cnt) printf "  avg RX: %.0f pps\n", sum/cnt}' /tmp/baseline_net.txt
