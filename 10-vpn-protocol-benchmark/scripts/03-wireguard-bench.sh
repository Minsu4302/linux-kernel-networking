#!/bin/bash
# WireGuard 벤치마크
# 사전 조건: Topic 09에서 생성한 키(/etc/wireguard/privatekey, wg0.conf)가 존재해야 함
# lab-vm-01에서 실행. lab-vm-02에서 'sudo wg-quick up wg0 && iperf3 -s' 선행 필요.
set -e

WG_SERVER="10.0.0.2"   # WireGuard IP of lab-vm-02

echo "=== WireGuard 인터페이스 시작 ==="
sudo wg-quick up wg0 2>/dev/null || echo "  이미 up 상태"
sleep 1
sudo wg show wg0 | grep -E "public key|listening"
echo ""

echo "=== [WireGuard] Throughput 측정 (30초, 4스트림) ==="
mpstat 1 35 > /tmp/wg_cpu.txt &
iperf3 -c "$WG_SERVER" -t 30 -P 4 | tail -4
wait
echo ""

echo "=== [WireGuard] CPU Average ==="
awk '/Average/ {printf "  usr=%.1f%% sys=%.1f%% sirq=%.1f%% idle=%.1f%%\n", $2, $4, $6, $12}' /tmp/wg_cpu.txt
echo ""

echo "=== [WireGuard] 지연시간 (ping 100회) ==="
ping -c 100 "$WG_SERVER" | tail -2
