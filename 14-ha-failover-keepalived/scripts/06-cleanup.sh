#!/bin/bash
# Keepalived 중지 및 설정 제거 — vm-02, vm-03에서 실행
set -e

echo "=== Keepalived 중지 ==="
sudo systemctl stop keepalived 2>/dev/null && echo "  중지 완료" || echo "  이미 중지됨"
sudo systemctl disable keepalived 2>/dev/null || true

echo ""
echo "=== nginx 중지 ==="
sudo systemctl stop nginx 2>/dev/null && echo "  중지 완료" || echo "  이미 중지됨"

echo ""
echo "=== 설정 파일 제거 ==="
sudo rm -f /etc/keepalived/keepalived.conf /etc/keepalived/notify.sh
echo "  완료"

echo ""
echo "=== 정리 완료 ==="
