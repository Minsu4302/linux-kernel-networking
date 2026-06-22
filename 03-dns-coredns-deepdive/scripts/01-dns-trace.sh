#!/bin/bash
# tcpdump로 DNS 쿼리 패킷을 캡처하면서 dig로 조회해 실제 재귀 조회 흐름을 관찰한다.
# 주의: 8.8.8.8은 재귀 리졸버이므로 VM에서는 단일 쿼리/응답만 보인다.
#       root → TLD → authoritative 반복 조회는 8.8.8.8 내부에서 처리된다.
set -e

echo "=== DNS 재귀 조회 패킷 추적 ==="
echo "현재 nameserver: $(grep nameserver /etc/resolv.conf | head -1)"
echo ""

sudo tcpdump -i any -n port 53 -l 2>/dev/null &
TCPDUMP_PID=$!
sleep 1

echo "--- dig google.com ---"
dig google.com +noall +answer +stats 2>/dev/null | grep -E "^google|Query time"

sleep 1
kill "$TCPDUMP_PID"
wait "$TCPDUMP_PID" 2>/dev/null || true

echo ""
echo "핵심 관찰:"
echo "  - Out: VM → 8.8.8.8  (단일 재귀 쿼리)"
echo "  - In:  8.8.8.8 → VM  (최종 A 레코드)"
echo "  - root/TLD/Auth 반복 조회는 8.8.8.8 내부에서 발생 (보이지 않음)"
