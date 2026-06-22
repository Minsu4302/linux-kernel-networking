#!/bin/bash
# 벤치마크용 백엔드 HTTP 서버 3대를 127.0.0.1:8081/8082/8083에 띄운다.
set -e

PIDS_FILE="/tmp/lb-backends.pids"
rm -f "$PIDS_FILE"

echo "=== 백엔드 HTTP 서버 3대 시작 ==="

for PORT in 8081 8082 8083; do
    PORT="$PORT" python3 -c '
import http.server, socketserver, os
port = int(os.environ["PORT"])
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"OK\n"
        self.send_response(200)
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass
with socketserver.TCPServer(("127.0.0.1", port), H) as s:
    s.serve_forever()
' &
    echo "$!" >> "$PIDS_FILE"
    echo "  :$PORT 시작 (PID $!)"
done

sleep 1

echo ""
echo "=== 응답 확인 ==="
for PORT in 8081 8082 8083; do
    curl -sf -o /dev/null -w "  :$PORT → HTTP %{http_code}\n" "http://127.0.0.1:$PORT/" \
        || echo "  :$PORT → FAIL"
done
