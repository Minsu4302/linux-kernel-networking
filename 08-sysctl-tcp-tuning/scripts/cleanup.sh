#!/bin/bash
# TCP sysctl을 기본값으로 복원하고 실험 프로세스를 종료한다.
# lab-vm-01에서 실행
set -e

echo "=== TCP sysctl 기본값 복원 ==="
sudo sysctl -w net.core.somaxconn=4096               >/dev/null && echo "  somaxconn = 4096"
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=512      >/dev/null && echo "  tcp_max_syn_backlog = 512"
sudo sysctl -w net.ipv4.tcp_tw_reuse=2               >/dev/null && echo "  tcp_tw_reuse = 2"
sudo sysctl -w net.ipv4.tcp_fin_timeout=60           >/dev/null && echo "  tcp_fin_timeout = 60"
sudo sysctl -w net.ipv4.ip_local_port_range="32768 60999" >/dev/null && echo "  ip_local_port_range = 32768-60999"
echo ""

echo "=== 남은 실험 프로세스 정리 ==="
sudo pkill -f "python3.*9999" 2>/dev/null && echo "  테스트 서버 종료" || echo "  실행 중인 서버 없음"
echo ""

echo "=== 복원 후 상태 ==="
sysctl net.core.somaxconn
sysctl net.ipv4.tcp_fin_timeout
sysctl net.ipv4.ip_local_port_range
echo ""
echo "=== 정리 완료 ==="
