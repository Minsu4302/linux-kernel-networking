#!/bin/bash
# Keepalived + nginx 설치 — vm-02, vm-03에서 실행
set -e

echo "=== Keepalived + nginx 설치 ==="
sudo apt-get update -q
sudo apt-get install -y keepalived nginx

echo ""
echo "=== nginx 자동 시작 비활성화 (Keepalived가 제어) ==="
sudo systemctl disable nginx
sudo systemctl stop nginx

echo ""
echo "=== 설치 완료 ==="
keepalived --version 2>&1 | head -1
nginx -v 2>&1
