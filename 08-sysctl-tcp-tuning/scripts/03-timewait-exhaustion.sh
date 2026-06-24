#!/bin/bash
# TIME_WAIT 소켓 누적과 에페머럴 포트 고갈을 재현한다.
# lab-vm-01에서 실행
set -e

echo "=== TIME_WAIT 누적 재현 ==="
echo ""

echo "[1] TIME_WAIT 전: $(ss -ant 2>/dev/null | grep -c TIME-WAIT || echo 0)개"

echo "[2] 50개 단기 HTTP 연결 발생 (매 연결이 TIME_WAIT 남김)"
for i in $(seq 1 50); do
    curl -s http://example.com -o /dev/null &
done
wait

echo "[3] TIME_WAIT 후: $(ss -ant | grep -c TIME-WAIT)개"
echo "    샘플:"
ss -ant | grep TIME-WAIT | head -3
echo ""

echo "=== 포트 고갈 재현 ==="
echo ""
ORIG_RANGE=$(sysctl -n net.ipv4.ip_local_port_range)

echo "[4] 에페머럴 포트 범위 축소: 28K → 100개 (10000-10099)"
sudo sysctl -w net.ipv4.ip_local_port_range="10000 10099" >/dev/null

echo "[5] 150개 연결 시도 (포트 100개뿐)"
python3 -c "
import socket, threading
ok, fail = 0, 0
lock = threading.Lock()
def connect():
    global ok, fail
    s = socket.socket()
    s.settimeout(2)
    try:
        s.connect(('93.184.216.34', 80))
        with lock: ok += 1
        s.close()
    except:
        with lock: fail += 1
threads = [threading.Thread(target=connect) for _ in range(150)]
[t.start() for t in threads]
[t.join() for t in threads]
print(f'  성공: {ok}, 실패: {fail}')
print(f'  실패 원인: EADDRNOTAVAIL (할당 가능한 에페머럴 포트 없음)')
"

sudo sysctl -w net.ipv4.ip_local_port_range="$ORIG_RANGE" >/dev/null
echo ""
echo "포트 범위 복구: $(sysctl -n net.ipv4.ip_local_port_range)"
echo ""

echo "포인트:"
echo "  - TIME_WAIT 소켓은 기본 60초(tcp_fin_timeout) 동안 포트를 점유"
echo "  - 초당 500개 연결 서비스 → 60초 × 500 = 30000 TIME_WAIT → 기본 28K 범위 고갈"
echo "  - 해결: ip_local_port_range 확장 또는 tcp_tw_reuse=1"
