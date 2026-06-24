#!/bin/bash
# pkt_counter XDP 프로그램을 로드하고 프로토콜별 수신 패킷 수를 관찰한다.
# lab-vm-01에서 실행. 01-build.sh를 먼저 실행해야 한다.
set -e

BUILD_DIR="$HOME/ebpf-lab"
IFACE="ens4"   # 환경에 맞게 수정

echo "=== pkt_counter XDP 로드 (generic 모드) ==="
# GCP virtio-net은 native XDP 미지원 → xdpgeneric(SKB 모드) 사용
sudo ip link set dev "$IFACE" xdpgeneric obj "$BUILD_DIR/pkt_counter.o" sec xdp
echo "  로드 완료: $(ip link show "$IFACE" | grep 'prog/xdp')"
echo ""

# BPF map ID 획득
MAP_ID=$(sudo bpftool map show | grep proto_count | awk '{print $1}' | tr -d ':')
echo "  proto_count map ID: $MAP_ID"
echo ""

read_counts() {
    echo -n "  ICMP (proto=1):  "; sudo bpftool map lookup id "$MAP_ID" key 0x01 0x00 0x00 0x00
    echo -n "  TCP  (proto=6):  "; sudo bpftool map lookup id "$MAP_ID" key 0x06 0x00 0x00 0x00
    echo -n "  UDP  (proto=17): "; sudo bpftool map lookup id "$MAP_ID" key 0x11 0x00 0x00 0x00
}

echo "=== 트래픽 발생 전 카운트 ==="
read_counts

echo ""
echo "=== 트래픽 발생 (ICMP ping 3개 + DNS + HTTP) ==="
ping -c3 8.8.8.8 > /dev/null &
dig google.com > /dev/null &
curl -s http://example.com > /dev/null &
wait

echo ""
echo "=== 트래픽 발생 후 카운트 ==="
read_counts
echo ""

echo "포인트:"
echo "  - XDP는 ingress(수신) 경로에 붙으므로 송신 패킷은 카운트 안 됨"
echo "  - ICMP: ping -c3이 보낸 echo reply 3개 = +3"
echo "  - UDP: DNS 응답 패킷 카운트"
echo "  - TCP: HTTP 응답 패킷 카운트"

echo ""
echo "XDP 언로드 (다음 스크립트 실행 전 또는 cleanup.sh 사용)"
sudo ip link set dev "$IFACE" xdpgeneric off
