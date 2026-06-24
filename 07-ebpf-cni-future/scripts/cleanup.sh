#!/bin/bash
# XDP 프로그램을 언로드하고 빌드 산출물을 삭제한다.
# lab-vm-01에서 실행
set -e

IFACE="ens4"

echo "=== XDP 언로드 ==="
if ip link show "$IFACE" | grep -q xdp; then
    sudo ip link set dev "$IFACE" xdpgeneric off 2>/dev/null || \
    sudo ip link set dev "$IFACE" xdp off 2>/dev/null
    echo "  $IFACE XDP 언로드 완료"
else
    echo "  $IFACE에 XDP 프로그램 없음 (이미 언로드됨)"
fi

echo ""
echo "=== 남은 XDP BPF 프로그램 확인 ==="
sudo bpftool prog show 2>/dev/null | grep xdp || echo "  없음"

echo ""
echo "=== 정리 완료 ==="
echo "빌드 파일(~/ebpf-lab/*.o)은 수동으로 삭제하세요:"
echo "  rm -f ~/ebpf-lab/pkt_counter.o ~/ebpf-lab/drop_icmp.o"
