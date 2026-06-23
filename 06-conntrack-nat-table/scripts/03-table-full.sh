#!/bin/bash
# nf_conntrack 테이블을 고갈시켜 신규 연결이 조용히 드롭되는 장애를 재현한다.
# lab-vm-01에서 실행
#
# 주의: nf_conntrack_max를 64로 줄이지만 기존 ESTABLISHED SSH는 드롭되지 않음.
#       신규 연결만 실패하므로 SSH 세션은 안전하다.
set -e

echo "=== nf_conntrack 테이블 고갈 재현 ==="
echo ""

# 환경 구성
echo "[1] 테스트 환경 구성 (netns + veth + HTTP 서버)"
sudo ip netns add test-ns 2>/dev/null || true
sudo ip link add veth-host type veth peer name veth-ns 2>/dev/null || true
sudo ip link set veth-ns netns test-ns
sudo ip addr add 10.99.0.1/24 dev veth-host 2>/dev/null || true
sudo ip netns exec test-ns ip addr add 10.99.0.2/24 dev veth-ns 2>/dev/null || true
sudo ip link set veth-host up
sudo ip netns exec test-ns ip link set veth-ns up
python3 -m http.server 8888 &>/dev/null &
HTTP_PID=$!
sleep 1
echo "  완료 (HTTP 서버 PID=$HTTP_PID)"
echo ""

# max를 64로 축소
echo "[2] nf_conntrack_max를 64로 임시 축소"
ORIGINAL_MAX=$(cat /proc/sys/net/netfilter/nf_conntrack_max)
sudo sysctl -w net.netfilter.nf_conntrack_max=64 >/dev/null
echo "  현재 카운트: $(sudo conntrack -C) / 64"
echo ""

# 100개 연결 시도
echo "[3] 네임스페이스에서 100개 연결 시도 (64개 넘으면 드롭)"
sudo ip netns exec test-ns python3 -c "
import socket, time
sockets = []
for i in range(100):
    try:
        s = socket.socket()
        s.settimeout(2)
        s.connect(('10.99.0.1', 8888))
        sockets.append(s)
        if i % 10 == 0:
            print(f'  {i}개 연결 성공')
    except Exception as e:
        print(f'  {i}번째 실패: {e}')
print(f'최종 성공: {len(sockets)}개')
time.sleep(2)
"
echo ""

# 결과 확인
echo "[4] 결과 확인"
echo "  테이블 카운트: $(sudo conntrack -C) / 64"
echo ""
echo "[5] dmesg에서 table full 로그"
sudo dmesg | grep -i "conntrack.*table full" | tail -5
echo ""

echo "포인트:"
echo "  - 실패 모드: 'connection refused(RST)' 가 아닌 'timed out'"
echo "  → 커널이 SYN을 조용히 드롭 → 클라이언트는 응답 없이 대기 → 타임아웃"
echo "  → 실제 장애에서 원인 파악이 어려운 이유"

# 복구
echo ""
echo "[6] nf_conntrack_max 원래 값($ORIGINAL_MAX)으로 복구"
sudo sysctl -w net.netfilter.nf_conntrack_max="$ORIGINAL_MAX" >/dev/null
echo "  복구 후 카운트: $(sudo conntrack -C) / $ORIGINAL_MAX"

# 정리
kill "$HTTP_PID" 2>/dev/null || true
sudo ip link del veth-host 2>/dev/null || true
sudo ip netns del test-ns 2>/dev/null || true
