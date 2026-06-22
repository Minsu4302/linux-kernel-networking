#!/bin/bash
# 벤치마크에서 생성한 모든 프로세스와 설정을 제거한다.
set -e

echo "=== 정리 시작 ==="

# 백엔드 HTTP 서버 종료
if [ -f /tmp/lb-backends.pids ]; then
    while IFS= read -r pid; do
        kill "$pid" 2>/dev/null || true
    done < /tmp/lb-backends.pids
    rm -f /tmp/lb-backends.pids
    echo "  백엔드 서버 종료"
fi

# HAProxy 종료
if [ -f /tmp/lb-haproxy.pid ]; then
    sudo kill "$(cat /tmp/lb-haproxy.pid)" 2>/dev/null || true
    rm -f /tmp/lb-haproxy.pid
fi
sudo pkill -9 -f 'haproxy.*lb-haproxy' 2>/dev/null || true
echo "  HAProxy 종료"

# Nginx 종료
if [ -f /tmp/lb-nginx.pid ]; then
    sudo kill "$(cat /tmp/lb-nginx.pid)" 2>/dev/null || true
    rm -f /tmp/lb-nginx.pid
fi
sudo pkill -9 nginx 2>/dev/null || true
echo "  Nginx 종료"

# IPVS 초기화 및 VIP 제거
sudo ipvsadm -C 2>/dev/null && echo "  IPVS 규칙 초기화"
sudo ip addr del 10.96.0.100/32 dev lo 2>/dev/null || true

# 임시 설정 파일 삭제
rm -f /tmp/lb-haproxy-l4.cfg /tmp/lb-haproxy-l7.cfg \
      /tmp/lb-nginx.cfg /tmp/lb-nginx-err.log

echo "=== 정리 완료 ==="
