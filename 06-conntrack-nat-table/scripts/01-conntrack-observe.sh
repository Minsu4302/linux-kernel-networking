#!/bin/bash
# nf_conntrack 테이블 현재 상태를 관찰한다.
# lab-vm-01에서 실행
set -e

echo "=== conntrack 도구 설치 확인 ==="
if ! command -v conntrack &>/dev/null; then
    sudo apt install -y conntrack
fi
echo "conntrack $(conntrack --version 2>&1 | head -1)"
echo ""

echo "=== nf_conntrack 테이블 한계 ==="
echo "  max     : $(cat /proc/sys/net/netfilter/nf_conntrack_max)"
echo "  buckets : $(cat /proc/sys/net/netfilter/nf_conntrack_buckets)"
echo "  count   : $(cat /proc/sys/net/netfilter/nf_conntrack_count)"
echo ""

echo "=== 전체 conntrack 엔트리 ==="
sudo conntrack -L
echo ""

echo "=== 프로토콜별 요약 ==="
echo "  TCP  ESTABLISHED : $(sudo conntrack -L 2>/dev/null | grep -c 'ESTABLISHED' || echo 0)"
echo "  TCP  TIME_WAIT   : $(sudo conntrack -L 2>/dev/null | grep -c 'TIME_WAIT' || echo 0)"
echo "  UDP              : $(sudo conntrack -L 2>/dev/null | grep -c '^udp' || echo 0)"
echo "  ICMP             : $(sudo conntrack -L 2>/dev/null | grep -c '^icmp' || echo 0)"
echo ""

echo "포인트:"
echo "  - 각 엔트리는 '원본방향 + 응답방향'을 한 줄에 기록 (양방향 추적)"
echo "  - TCP는 상태(ESTABLISHED/TIME_WAIT 등) 포함, ICMP는 TTL 카운트다운"
echo "  - 169.254.169.254:80 = GCP 메타데이터 서버 폴링"
echo "  - dport=22 ESTABLISHED = 현재 SSH 세션"
