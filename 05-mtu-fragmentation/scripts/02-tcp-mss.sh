#!/bin/bash
# VXLAN 터널 위 TCP 연결의 MSS 협상을 tcpdump로 관찰한다.
# lab-vm-01에서 실행. lab-vm-02에서 먼저 TCP 서버를 실행해야 한다.
#
# vm-02 사전 준비:
#   python3 -c "
#   import socketserver, socket
#   class H(socketserver.BaseRequestHandler):
#       def handle(self):
#           d = self.request.recv(65536)
#           self.request.sendall(b'OK ' + str(len(d)).encode() + b'\n')
#   with socketserver.TCPServer(('192.168.100.2', 9999), H) as s:
#       s.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
#       print('서버 시작'); s.serve_forever()
#   " &
set -e

SERVER_IP="192.168.100.2"  # vm-02 VXLAN IP (환경에 맞게 수정)
PORT=9999

echo "=== TCP MSS 관찰 ==="
echo "VXLAN MTU 1410 → 이론 MSS = 1410 − 40(IP 20 + TCP 20) = 1370"
echo ""

echo "[1] 패킷 캡처 시작 (vxlan0, SYN/SYN-ACK 필터)"
sudo tcpdump -i vxlan0 -n -v 'tcp[13] & 2 != 0' -l 2>/dev/null &
TCPDUMP_PID=$!
sleep 1

echo "[2] TCP 연결 (nc → $SERVER_IP:$PORT)"
echo "테스트" | nc -w2 "$SERVER_IP" "$PORT" 2>/dev/null || true

sleep 1
kill "$TCPDUMP_PID"
wait "$TCPDUMP_PID" 2>/dev/null || true

echo ""
echo "포인트:"
echo "  SYN     의 options [mss N] = 클라이언트 제안 MSS"
echo "  SYN-ACK 의 options [mss N] = 서버 제안 MSS"
echo "  실제 사용 MSS = min(클라이언트, 서버)"
echo "  두 VM 모두 vxlan0(MTU 1410) 경유 → 양쪽 모두 1370 제안"
