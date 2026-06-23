#!/bin/bash
# MSS Clamping iptables 규칙을 전부 제거한다.
# lab-vm-01에서 실행
set -e

echo "=== MSS Clamping iptables 규칙 제거 ==="

for CHAIN in OUTPUT FORWARD; do
    while sudo iptables -t mangle -D "$CHAIN" \
          -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null; do
        echo "  mangle $CHAIN --clamp-mss-to-pmtu 삭제"
    done
    while sudo iptables -t mangle -D "$CHAIN" \
          -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 500 2>/dev/null; do
        echo "  mangle $CHAIN --set-mss 500 삭제"
    done
done

echo ""
echo "--- mangle OUTPUT 현재 상태 ---"
sudo iptables -t mangle -L OUTPUT -n --line-numbers
echo ""
echo "--- mangle FORWARD 현재 상태 ---"
sudo iptables -t mangle -L FORWARD -n --line-numbers

echo ""
echo "=== 정리 완료 ==="
