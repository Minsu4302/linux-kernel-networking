#!/bin/bash
# VXLAN 터널의 MTU 경계를 ICMP DF 비트로 확인한다.
# lab-vm-01에서 실행. 04번 실습의 VXLAN 터널(vxlan0)이 설정된 상태를 전제.
#
# 환경:
#   VM1(lab-vm-01): 10.178.0.2, VXLAN IP 192.168.100.1
#   VM2(lab-vm-02): 10.178.0.3, VXLAN IP 192.168.100.2
set -e

TARGET="192.168.100.2"  # vm-02 VXLAN IP (환경에 맞게 수정)

echo "=== vxlan0 MTU 확인 ==="
ip link show vxlan0 | grep -o "mtu [0-9]*"
echo "이론: GCP ens4 MTU 1460 − VXLAN 오버헤드 50 = vxlan0 MTU 1410"
echo ""

echo "=== MTU 경계 테스트 (DF bit on, ICMP 페이로드 크기 변화) ==="
echo "공식: 전체 패킷 = 페이로드 + 8(ICMP) + 20(IP) = 페이로드 + 28"
echo "허용 최대 페이로드 = 1410 − 28 = 1382 바이트"
echo ""

echo "[1] -s 1382 (1382+28=1410, vxlan0 MTU와 정확히 일치) → 성공 예상"
ping -c1 -M do -s 1382 "$TARGET" && echo "  결과: 성공 ✓" || echo "  결과: 실패 ✗"
echo ""

echo "[2] -s 1383 (1383+28=1411, vxlan0 MTU 1410 초과) → 실패 예상"
ping -c1 -M do -s 1383 "$TARGET" && echo "  결과: 성공 ✓" || echo "  결과: 실패 ✗ (message too long)"
echo ""

echo "=== 결론 ==="
echo "ICMP DF 패킷 허용 최대 페이로드 = 1382 바이트"
echo "1383 바이트부터 커널이 EMSGSIZE 반환 → 'message too long, mtu=1410'"
