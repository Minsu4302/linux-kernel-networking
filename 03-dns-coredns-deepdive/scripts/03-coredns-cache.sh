#!/bin/bash
# CoreDNS를 로컬 리졸버로 실행하고 캐시 MISS vs HIT 레이턴시를 비교한다.
# CoreDNS는 포트 5300에서 실행 (1024 이하 포트는 root 필요)
set -e

COREFILE_DIR="/tmp/coredns-test"
mkdir -p "$COREFILE_DIR"

tee "$COREFILE_DIR/Corefile" > /dev/null << 'EOF'
. {
    forward . 8.8.8.8
    cache 60
    log
    errors
}
EOF

echo "=== CoreDNS 시작 (포트 5300) ==="
coredns -conf "$COREFILE_DIR/Corefile" -p 5300 > /tmp/coredns.log 2>&1 &
COREDNS_PID=$!
sleep 2

if ! kill -0 "$COREDNS_PID" 2>/dev/null; then
    echo "CoreDNS 시작 실패. 로그:" >&2
    cat /tmp/coredns.log >&2
    exit 1
fi

echo "PID: $COREDNS_PID"
echo ""

echo "--- 1차 쿼리: Cache MISS (8.8.8.8 왕복 발생) ---"
time dig @127.0.0.1 -p 5300 google.com +short +time=3

echo ""
echo "--- 2차 쿼리: Cache HIT (CoreDNS 로컬 응답) ---"
time dig @127.0.0.1 -p 5300 google.com +short +time=3

echo ""
echo "--- CoreDNS 로그 (qr,aa = 캐시 히트 표시) ---"
cat /tmp/coredns.log

echo ""
echo "=== CoreDNS 종료 ==="
kill "$COREDNS_PID"
wait "$COREDNS_PID" 2>/dev/null || true
rm -f /tmp/coredns.log
rm -rf "$COREFILE_DIR"
