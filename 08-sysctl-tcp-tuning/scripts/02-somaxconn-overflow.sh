#!/bin/bash
# somaxconn을 축소해 accept queue 오버플로를 재현하고 nstat으로 드롭 카운터를 확인한다.
# lab-vm-01에서 실행
set -e

echo "=== somaxconn 오버플로 재현 ==="
echo "원리: somaxconn이 작으면 accept queue가 빨리 찬다."
echo "      accept queue 가득 → 새 연결의 ACK를 조용히 드롭 → 클라이언트 timeout"
echo ""

ORIG_MAX=$(sysctl -n net.core.somaxconn)
sudo sysctl -w net.core.somaxconn=5 >/dev/null

echo "[1] 오버플로 전 카운터"
BEFORE=$(nstat -az | grep TcpExtListenOverflows | awk '{print $2}')
echo "  TcpExtListenOverflows = $BEFORE"
echo ""

echo "[2] 느린 서버 시작 (listen backlog=3, 20초간 accept 안 함)"
python3 -c "
import socket, time, sys
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', 9999))
s.listen(3)
sys.stdout.flush()
time.sleep(20)
" &
SERVER_PID=$!
sleep 1

echo "[3] 50개 동시 연결 시도"
python3 -c "
import socket, threading
def go():
    s = socket.socket()
    s.settimeout(1)
    try:
        s.connect(('127.0.0.1', 9999))
        import time; time.sleep(15)
    except: pass
threads = [threading.Thread(target=go, daemon=True) for _ in range(50)]
[t.start() for t in threads]
import time; time.sleep(3)
" &
sleep 4

echo "[4] 오버플로 후 카운터"
AFTER=$(nstat -az | grep TcpExtListenOverflows | awk '{print $2}')
echo "  TcpExtListenOverflows = $AFTER  (+$((AFTER - BEFORE)) 드롭)"
echo ""

echo "[5] accept queue 상태 (ss -lnt)"
ss -lnt | grep -E "Recv-Q|9999"
echo "  Recv-Q = 대기 연결 수, Send-Q = 최대 backlog"
echo "  Recv-Q >= Send-Q: 오버플로 발생 중"

kill $SERVER_PID 2>/dev/null || true
wait 2>/dev/null || true
sudo sysctl -w net.core.somaxconn="$ORIG_MAX" >/dev/null
echo ""
echo "복구 완료 (somaxconn=$ORIG_MAX)"
