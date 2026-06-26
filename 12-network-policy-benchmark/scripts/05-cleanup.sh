#!/bin/bash
# iptables 규칙 및 ipset 전체 정리 — lab-vm-02에서 실행
set -e

echo "=== iptables INPUT 체인 초기화 ==="
sudo iptables -F INPUT
echo "  완료"

echo ""
echo "=== ipset 정리 ==="
sudo ipset destroy dummy_ips 2>/dev/null && echo "  dummy_ips 삭제" || echo "  dummy_ips 없음"
sudo ipset destroy allow_ips 2>/dev/null && echo "  allow_ips 삭제" || echo "  allow_ips 없음"

echo ""
echo "=== 정리 완료 ==="
sudo iptables -L INPUT -n
