#!/bin/bash
# ndots:5 + search domain 이 만드는 불필요한 DNS 쿼리를 tcpdump로 직접 계수한다.
# dig는 resolv.conf의 ndots를 무시하므로 glibc resolver를 사용하는 host 명령을 사용한다.
set -e

RESOLV_BAK="/tmp/resolv.conf.ndots-bak"
sudo cp /etc/resolv.conf "$RESOLV_BAK"

cleanup() {
    sudo cp "$RESOLV_BAK" /etc/resolv.conf
    echo "(resolv.conf 복원 완료)"
}
trap cleanup EXIT

echo "=== K8s pod resolv.conf 시뮬레이션 ==="
sudo tee /etc/resolv.conf > /dev/null << 'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
EOF

echo ""
echo "--- [A] host google.com  (dot 1개 < ndots:5 → search domain 먼저) ---"
TMPFILE=$(mktemp)
sudo tcpdump -i any -n port 53 -l 2>/dev/null > "$TMPFILE" &
TCPDUMP_PID=$!
sleep 1

START_A=$(date +%s%3N)
host google.com > /dev/null 2>&1 || true
END_A=$(date +%s%3N)

sleep 1
kill "$TCPDUMP_PID"
wait "$TCPDUMP_PID" 2>/dev/null || true

A_QUERIES=$(grep -c " Out " "$TMPFILE" 2>/dev/null || echo 0)
echo "  A 레코드 쿼리 수 (Out 패킷): $A_QUERIES"
echo "  소요 시간: $((END_A - START_A))ms"
grep " Out " "$TMPFILE" | awk '{print "  " $7}' 2>/dev/null || true

echo ""
echo "--- [B] host google.com.  (FQDN, 끝에 점 → search 무시) ---"
TMPFILE2=$(mktemp)
sudo tcpdump -i any -n port 53 -l 2>/dev/null > "$TMPFILE2" &
TCPDUMP_PID=$!
sleep 1

START_B=$(date +%s%3N)
host google.com. > /dev/null 2>&1 || true
END_B=$(date +%s%3N)

sleep 1
kill "$TCPDUMP_PID"
wait "$TCPDUMP_PID" 2>/dev/null || true

B_QUERIES=$(grep -c " Out " "$TMPFILE2" 2>/dev/null || echo 0)
echo "  A 레코드 쿼리 수 (Out 패킷): $B_QUERIES"
echo "  소요 시간: $((END_B - START_B))ms"

rm -f "$TMPFILE" "$TMPFILE2"

echo ""
echo "=== 결과 ==="
echo "  google.com  (ndots:5 적용): 쿼리 ${A_QUERIES}회, $((END_A - START_A))ms"
echo "  google.com. (FQDN):         쿼리 ${B_QUERIES}회, $((END_B - START_B))ms"
