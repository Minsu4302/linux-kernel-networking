#!/bin/bash
# WireGuard 인터페이스 종료 및 정리
# 3대 모두 동일하게 실행
set -e

echo "=== WireGuard 인터페이스 종료 ==="
if sudo wg show wg0 > /dev/null 2>&1; then
    sudo wg-quick down wg0
    echo "  wg0 종료 완료"
else
    echo "  wg0가 이미 down 상태"
fi

echo ""
echo "=== 설정 파일 백업 (확인용) ==="
ls -la /etc/wireguard/
echo ""
echo "  실습 완료 후 삭제: sudo rm /etc/wireguard/wg0.conf /etc/wireguard/privatekey /etc/wireguard/pubkey"
