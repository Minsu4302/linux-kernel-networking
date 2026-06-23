#!/bin/bash
# nf_conntrack 관련 sysctl 현재값을 확인하고 실무 권장값을 적용한다.
# lab-vm-01에서 실행
set -e

echo "=== nf_conntrack sysctl 현재값 ==="
printf "  %-50s %s\n" "net.netfilter.nf_conntrack_max"                 "$(sysctl -n net.netfilter.nf_conntrack_max)"
printf "  %-50s %s\n" "net.netfilter.nf_conntrack_buckets"             "$(sysctl -n net.netfilter.nf_conntrack_buckets)"
printf "  %-50s %s\n" "net.netfilter.nf_conntrack_tcp_timeout_established" "$(sysctl -n net.netfilter.nf_conntrack_tcp_timeout_established)"
printf "  %-50s %s\n" "net.netfilter.nf_conntrack_tcp_timeout_time_wait"   "$(sysctl -n net.netfilter.nf_conntrack_tcp_timeout_time_wait)"
echo ""

echo "=== 실무 권장값 적용 ==="
# established timeout: 기본 5일(432000) → 30분(1800)으로 축소
# 좀비 연결(앱 레벨에서 끊어졌지만 RST/FIN 없이 사라진 TCP)이 테이블 점유 기간 단축
sudo sysctl -w net.netfilter.nf_conntrack_tcp_timeout_established=1800
echo "  timeout_established: 432000 → 1800 (5일 → 30분)"

# time_wait timeout: 기본 120s → 30s
sudo sysctl -w net.netfilter.nf_conntrack_tcp_timeout_time_wait=30
echo "  timeout_time_wait:   120 → 30"
echo ""

echo "=== 영구 적용 방법 (/etc/sysctl.d/99-conntrack.conf) ==="
cat << 'EOF'
# K8s/고부하 환경 기준 권장값
net.netfilter.nf_conntrack_max = 524288
net.netfilter.nf_conntrack_buckets = 131072
net.netfilter.nf_conntrack_tcp_timeout_established = 1800
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
EOF
echo ""
echo "적용 명령:"
echo "  sudo sysctl -p /etc/sysctl.d/99-conntrack.conf"
echo ""

echo "=== 파라미터 설명 ==="
echo "  nf_conntrack_max       : 추적 가능한 최대 연결 수. 부족하면 신규 연결 드롭"
echo "  nf_conntrack_buckets   : 해시 테이블 버킷 수. max/4 ~ max 사이 권장"
echo "                           클수록 해시 충돌 감소(조회 속도 ↑), 메모리 ↑"
echo "  timeout_established    : TCP ESTABLISHED 엔트리 유지 시간"
echo "                           너무 길면 좀비 연결이 테이블 점유"
echo "  timeout_time_wait      : TCP TIME_WAIT 엔트리 유지 시간"
echo "                           너무 짧으면 혼선(동일 5-tuple 재사용) 위험"
