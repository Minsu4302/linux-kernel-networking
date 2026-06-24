#!/bin/bash
# TCP 커널 파라미터 현재값과 소켓 상태를 확인한다.
# lab-vm-01에서 실행
set -e

echo "=== TCP 핵심 sysctl 현재값 ==="
printf "  %-50s %s\n" "net.core.somaxconn"              "$(sysctl -n net.core.somaxconn)"
printf "  %-50s %s\n" "net.ipv4.tcp_max_syn_backlog"    "$(sysctl -n net.ipv4.tcp_max_syn_backlog)"
printf "  %-50s %s\n" "net.ipv4.tcp_tw_reuse"           "$(sysctl -n net.ipv4.tcp_tw_reuse)"
printf "  %-50s %s\n" "net.ipv4.tcp_fin_timeout"        "$(sysctl -n net.ipv4.tcp_fin_timeout)"
printf "  %-50s %s\n" "net.ipv4.ip_local_port_range"    "$(sysctl -n net.ipv4.ip_local_port_range)"
echo ""

echo "=== 현재 소켓 상태 (ss -s) ==="
ss -s
echo ""

echo "=== TIME_WAIT 소켓 현황 ==="
TW=$(ss -ant | grep -c TIME-WAIT 2>/dev/null || echo 0)
echo "  TIME_WAIT: ${TW}개"
echo ""

echo "=== ListenOverflow 누적 카운터 ==="
nstat -az | grep -E "ListenOverflow|ListenDrop"
echo ""

echo "파라미터 설명:"
echo "  somaxconn          : accept queue 최대 크기. 초과 시 연결 조용히 드롭"
echo "  tcp_max_syn_backlog: SYN_RECV queue 크기"
echo "  tcp_tw_reuse       : 0=비활성, 1=전체, 2=루프백만 TIME_WAIT 재사용"
echo "  tcp_fin_timeout    : TIME_WAIT 유지 시간(초)"
echo "  ip_local_port_range: 에페머럴 포트 범위. 좁으면 포트 고갈 발생"
