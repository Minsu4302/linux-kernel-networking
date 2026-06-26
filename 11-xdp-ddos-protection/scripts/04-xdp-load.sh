#!/bin/bash
# XDP 프로그램 로드 + 블랙리스트 등록 + CPU 측정 — lab-vm-02에서 실행
# 사전 조건: 01-build.sh 실행 완료
# lab-vm-01에서 05-attacker-flood.sh 를 동시에 실행해야 한다.
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OBJ="$REPO_DIR/build/xdp_drop.o"
ATTACKER_IP="10.178.0.2"
IFACE=$(ip route | awk '/default/{print $5; exit}')
DURATION=20

echo "=== XDP 프로그램 로드 (xdpgeneric — GCP virtio-net 제약) ==="
sudo ip link set dev "$IFACE" xdpgeneric obj "$OBJ" sec xdp
echo "  로드 완료: $IFACE"
sudo bpftool prog show | grep xdp | tail -1
echo ""

echo "=== 블랙리스트에 공격자 IP 등록: $ATTACKER_IP ==="
# IPv4를 네트워크 바이트 오더(big-endian) hex로 변환
HEX=$(python3 -c "
import socket
ip = '$ATTACKER_IP'
raw = socket.inet_aton(ip)
print(' '.join(f'{b:02x}' for b in raw))
")
echo "  $ATTACKER_IP → hex: $HEX"
MAP_ID=$(sudo bpftool map show | grep blocklist | awk '{print $1}' | tr -d ':')
sudo bpftool map update id "$MAP_ID" \
    key hex $HEX \
    value hex 00 00 00 00 00 00 00 00
echo "  blocklist 등록 완료 (map id: $MAP_ID)"
echo ""

echo "=== XDP 방어 CPU 측정 시작 (${DURATION}초) ==="
echo "  → 지금 lab-vm-01에서 05-attacker-flood.sh 를 실행하세요"
echo ""

# 측정 전 카운터 초기화 기준값 읽기
CNT_ID=$(sudo bpftool map show | grep counters | awk '{print $1}' | tr -d ':')

mpstat 1 $DURATION > /tmp/xdp_cpu.txt &
sar -n DEV 1 $DURATION 2>/dev/null | grep "$IFACE" > /tmp/xdp_net.txt &
wait

echo "=== [XDP] CPU 평균 ==="
awk '/Average/ {printf "  usr=%.1f%% sys=%.1f%% sirq=%.1f%% idle=%.1f%%  (사용률=%.1f%%)\n",
    $2, $4, $6, $12, 100-$12}' /tmp/xdp_cpu.txt

echo ""
echo "=== [XDP] 드롭 카운터 ==="
echo "  blocklist (IP별 드롭 수):"
sudo bpftool map dump id "$MAP_ID" 2>/dev/null | grep -A1 "key"
echo ""
echo "  counters [0]=총수신 [1]=총드롭:"
sudo bpftool map dump id "$CNT_ID" 2>/dev/null
echo ""
echo "XDP 프로그램을 유지합니다. 종료하려면 07-cleanup.sh 실행."
