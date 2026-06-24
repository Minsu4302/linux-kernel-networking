#!/bin/bash
# 고부하 환경 권장 TCP sysctl 튜닝을 적용하고 설명한다.
# lab-vm-01에서 실행
set -e

echo "=== 현재값 vs 권장값 비교 ==="
printf "  %-45s %-12s %s\n" "파라미터" "현재" "권장"
printf "  %-45s %-12s %s\n" "---------" "----" "----"
printf "  %-45s %-12s %s\n" "net.core.somaxconn"               "$(sysctl -n net.core.somaxconn)"             "65535"
printf "  %-45s %-12s %s\n" "net.ipv4.tcp_max_syn_backlog"     "$(sysctl -n net.ipv4.tcp_max_syn_backlog)"   "8192"
printf "  %-45s %-12s %s\n" "net.ipv4.tcp_tw_reuse"            "$(sysctl -n net.ipv4.tcp_tw_reuse)"          "1"
printf "  %-45s %-12s %s\n" "net.ipv4.tcp_fin_timeout"         "$(sysctl -n net.ipv4.tcp_fin_timeout)"       "30"
printf "  %-45s %-12s %s\n" "net.ipv4.ip_local_port_range"     "$(sysctl -n net.ipv4.ip_local_port_range)"   "1024 65535"
echo ""

echo "=== 튜닝 적용 ==="
sudo sysctl -w net.core.somaxconn=65535              >/dev/null && echo "  somaxconn = 65535"
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=8192     >/dev/null && echo "  tcp_max_syn_backlog = 8192"
sudo sysctl -w net.ipv4.tcp_tw_reuse=1               >/dev/null && echo "  tcp_tw_reuse = 1"
sudo sysctl -w net.ipv4.tcp_fin_timeout=30           >/dev/null && echo "  tcp_fin_timeout = 30"
sudo sysctl -w net.ipv4.ip_local_port_range="1024 65535" >/dev/null && echo "  ip_local_port_range = 1024-65535"
echo ""

echo "=== 영구 적용 방법 (/etc/sysctl.d/99-tcp-tuning.conf) ==="
cat << 'EOF'
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.ip_local_port_range = 1024 65535
EOF
echo ""
echo "적용: sudo sysctl -p /etc/sysctl.d/99-tcp-tuning.conf"
echo ""

echo "=== 파라미터 설명 ==="
echo "  somaxconn        : accept queue 상한. listen(backlog)과 min() 취함"
echo "                     부족 시 → SYN_DROP (클라이언트 timeout)"
echo "  tcp_max_syn_backlog: SYN_RECV(half-open) queue 크기"
echo "                     SYN Flood 방어와 관련 (tcp_syncookies와 연동)"
echo "  tcp_tw_reuse     : TIME_WAIT 소켓의 로컬 포트를 새 아웃바운드 연결에 재사용"
echo "                     동일 목적지(IP:port)로 연결 시에만 작동"
echo "  tcp_fin_timeout  : TIME_WAIT 상태 유지 시간. 줄이면 포트 회전 빨라짐"
echo "                     너무 짧으면 동일 4-tuple 재사용 시 혼선 위험"
echo "  ip_local_port_range: 아웃바운드 연결에 쓸 에페머럴 포트 범위"
echo "                     범위 넓힐수록 동시 아웃바운드 연결 수 증가"
