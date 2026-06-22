#!/bin/bash
# 실습 리소스 정리 스크립트
# 다음 주제(02-l4-l7-loadbalancer-comparison) 시작 시 재사용 가능하도록
# VM은 삭제하지 않고 커널 오브젝트만 정리

set -e

echo "=== HTTP 서버 프로세스 종료 ==="
pkill -f "python3 -m http.server 8080" 2>/dev/null && echo "서버 종료" || echo "(실행 중인 서버 없음)"

echo "=== IPVS 가상 서버 초기화 ==="
ipvsadm -C 2>/dev/null && echo "IPVS 초기화 완료" || true

echo "=== iptables NAT 규칙 초기화 ==="
iptables -t nat -F 2>/dev/null && echo "iptables NAT 초기화 완료" || true
iptables -P FORWARD ACCEPT 2>/dev/null || true

echo "=== lo에서 ClusterIP 제거 ==="
ip addr del 10.96.0.1/32 dev lo 2>/dev/null && echo "10.96.0.1 제거" || echo "(없음)"

echo "=== network namespace 및 veth 제거 ==="
for ns in pod-a pod-b pod-c; do
    ip netns del $ns 2>/dev/null && echo "$ns 삭제" || echo "($ns 없음)"
done

echo "=== Linux bridge 제거 ==="
ip link set br0 down 2>/dev/null || true
ip link del br0 2>/dev/null && echo "br0 삭제" || echo "(br0 없음)"

echo "=== 임시 파일 정리 ==="
rm -rf /tmp/pod-a /tmp/pod-b /tmp/pod-c /tmp/bench.sh 2>/dev/null || true

echo ""
echo "=== 정리 완료 ==="
echo "남아있는 namespace: $(ip netns list 2>/dev/null || echo '없음')"
echo "남아있는 bridge: $(ip link show type bridge 2>/dev/null | grep -v br0 || echo '없음')"
