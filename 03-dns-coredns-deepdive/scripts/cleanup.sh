#!/bin/bash
# CoreDNS 프로세스 정리 및 임시 파일 삭제
set -e

echo "=== 정리 ==="

sudo pkill -9 coredns 2>/dev/null && echo "  CoreDNS 종료" || echo "  CoreDNS: 실행 중 아님"
sudo pkill -9 tcpdump 2>/dev/null || true

rm -rf /tmp/coredns-test /tmp/coredns.log /tmp/resolv.conf.ndots-bak

# ndots:5 실험 후 resolv.conf가 오염됐을 경우 복원
if grep -q "ndots" /etc/resolv.conf 2>/dev/null; then
    sudo tee /etc/resolv.conf > /dev/null << 'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
    echo "  resolv.conf 복원 (ndots:5 제거)"
fi

echo "=== 정리 완료 ==="
