#!/bin/bash
# iptables DROP 방어 + CPU 측정 — lab-vm-02에서 실행
# lab-vm-01에서 05-attacker-flood.sh 를 동시에 실행해야 한다.
set -e

ATTACKER_IP="10.178.0.2"
DURATION=20
IFACE=$(ip route | awk '/default/{print $5; exit}')

echo "=== iptables DROP 규칙 추가 ==="
sudo iptables -A INPUT -s "$ATTACKER_IP" -j DROP
echo "  규칙 적용: DROP from $ATTACKER_IP"
sudo iptables -L INPUT -n -v | grep "$ATTACKER_IP"
echo ""

echo "=== iptables 방어 CPU 측정 시작 (${DURATION}초) ==="
echo "  → 지금 lab-vm-01에서 05-attacker-flood.sh 를 실행하세요"
echo ""

mpstat 1 $DURATION > /tmp/iptables_cpu.txt &
sar -n DEV 1 $DURATION 2>/dev/null | grep "$IFACE" > /tmp/iptables_net.txt &
wait

echo "=== [iptables] CPU 평균 ==="
awk '/Average/ {printf "  usr=%.1f%% sys=%.1f%% sirq=%.1f%% idle=%.1f%%  (사용률=%.1f%%)\n",
    $2, $4, $6, $12, 100-$12}' /tmp/iptables_cpu.txt

echo ""
echo "=== [iptables] 드롭된 패킷 수 ==="
sudo iptables -L INPUT -n -v | grep "$ATTACKER_IP"

echo ""
echo "=== iptables 규칙 제거 ==="
sudo iptables -D INPUT -s "$ATTACKER_IP" -j DROP
echo "  규칙 제거 완료"
