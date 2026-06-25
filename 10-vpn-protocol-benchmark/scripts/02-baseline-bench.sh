#!/bin/bash
# Baseline 벤치마크 (VPN 없음, 물리 네트워크 직접)
# lab-vm-01에서 실행. lab-vm-02에서 'iperf3 -s' 선행 필요.
#
# 환경: lab-vm-01 10.178.0.2, lab-vm-02 10.178.0.3
set -e

SERVER="10.178.0.3"

echo "=== [Baseline] Throughput 측정 (30초, 4스트림) ==="
mpstat 1 35 > /tmp/baseline_cpu.txt &
iperf3 -c "$SERVER" -t 30 -P 4 | tail -4
wait
echo ""

echo "=== [Baseline] CPU Average ==="
awk '/Average/ {printf "  usr=%.1f%% sys=%.1f%% sirq=%.1f%% idle=%.1f%%\n", $2, $4, $6, $12}' /tmp/baseline_cpu.txt
echo ""

echo "=== [Baseline] 지연시간 (ping 100회) ==="
ping -c 100 "$SERVER" | tail -2
