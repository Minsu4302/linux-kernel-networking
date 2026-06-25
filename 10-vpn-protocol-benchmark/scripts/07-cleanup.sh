#!/bin/bash
# IPsec, WireGuard 정리
# lab-vm-01, lab-vm-02 동시에 실행
set -e

echo "=== WireGuard 종료 ==="
sudo wg-quick down wg0 2>/dev/null && echo "  wg0 종료" || echo "  wg0 이미 down"

echo ""
echo "=== IPsec 종료 ==="
sudo ipsec stop 2>/dev/null && echo "  ipsec 종료" || echo "  ipsec 이미 중지"

echo ""
echo "=== 정리 완료 ==="
echo "  GCP 방화벽 규칙 삭제 (Cloud Shell에서 실행):"
echo "  gcloud compute firewall-rules delete allow-ipsec-esp"
