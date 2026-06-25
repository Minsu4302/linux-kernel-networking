#!/bin/bash
# IPsec 벤치마크
# lab-vm-01에서 실행. lab-vm-02에서 'iperf3 -s' 선행 필요.
# IPsec transport mode: 물리 IP(10.178.0.3)로 보내면 커널이 자동 ESP 암호화
set -e

SERVER="10.178.0.3"

echo "=== IPsec SA 확인 ==="
sudo ipsec status | grep -E "ESTABLISHED|INSTALLED"
echo ""

echo "=== [IPsec] Throughput 측정 (30초, 4스트림) ==="
mpstat 1 35 > /tmp/ipsec_cpu.txt &
iperf3 -c "$SERVER" -t 30 -P 4 | tail -4
wait
echo ""

echo "=== [IPsec] CPU Average ==="
awk '/Average/ {printf "  usr=%.1f%% sys=%.1f%% sirq=%.1f%% idle=%.1f%%\n", $2, $4, $6, $12}' /tmp/ipsec_cpu.txt
echo ""

echo "=== [IPsec] 지연시간 (ping 100회) ==="
ping -c 100 "$SERVER" | tail -2
