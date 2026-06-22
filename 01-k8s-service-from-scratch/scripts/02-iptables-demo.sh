#!/bin/bash
# iptables DNAT + statistic 모듈로 K8s ClusterIP / NodePort 재현
#
# 전제: 01-setup-namespaces.sh 실행 완료
# ClusterIP: 10.96.0.1:80 → pod-a/b/c :8080 균등 분산
# NodePort:  127.0.0.1:30080 → ClusterIP (MASQUERADE 필요)
#
# statistic 확률 계산:
#   Rule1: P=1/3        → pod-a (약 33%)
#   Rule2: P=1/2        → pod-b (나머지 2/3 중 절반 = 약 33%)
#   Rule3: catch-all    → pod-c (나머지 약 33%)

set -e

echo "=== ClusterIP(10.96.0.1)를 lo에 추가 ==="
# iptables OUTPUT chain이 lo 기반 패킷을 가로채 DNAT하려면
# 커널이 10.96.0.1을 local 주소로 인식해야 함
ip addr add 10.96.0.1/32 dev lo 2>/dev/null || echo "(이미 존재)"

echo "=== 기존 NAT 규칙 초기화 ==="
iptables -t nat -F OUTPUT
iptables -t nat -F PREROUTING
iptables -t nat -F POSTROUTING

echo "=== FORWARD 허용 ==="
iptables -P FORWARD ACCEPT

echo "=== ClusterIP → Pod 분산 (OUTPUT: 호스트에서 curl 시 적용) ==="
iptables -t nat -A OUTPUT -d 10.96.0.1 -p tcp --dport 80 \
  -m statistic --mode random --probability 0.33333 \
  -j DNAT --to-destination 10.200.0.10:8080

iptables -t nat -A OUTPUT -d 10.96.0.1 -p tcp --dport 80 \
  -m statistic --mode random --probability 0.50000 \
  -j DNAT --to-destination 10.200.0.11:8080

iptables -t nat -A OUTPUT -d 10.96.0.1 -p tcp --dport 80 \
  -j DNAT --to-destination 10.200.0.12:8080

echo "=== NodePort(127.0.0.1:30080) → Pod 분산 (OUTPUT) ==="
iptables -t nat -A OUTPUT -p tcp --dport 30080 \
  -m statistic --mode random --probability 0.33333 \
  -j DNAT --to-destination 10.200.0.10:8080

iptables -t nat -A OUTPUT -p tcp --dport 30080 \
  -m statistic --mode random --probability 0.50000 \
  -j DNAT --to-destination 10.200.0.11:8080

iptables -t nat -A OUTPUT -p tcp --dport 30080 \
  -j DNAT --to-destination 10.200.0.12:8080

echo "=== NodePort(127.0.0.1:30080) → Pod 분산 (PREROUTING: 외부 트래픽) ==="
iptables -t nat -A PREROUTING -p tcp --dport 30080 \
  -m statistic --mode random --probability 0.33333 \
  -j DNAT --to-destination 10.200.0.10:8080

iptables -t nat -A PREROUTING -p tcp --dport 30080 \
  -m statistic --mode random --probability 0.50000 \
  -j DNAT --to-destination 10.200.0.11:8080

iptables -t nat -A PREROUTING -p tcp --dport 30080 \
  -j DNAT --to-destination 10.200.0.12:8080

echo "=== POSTROUTING MASQUERADE ==="
# 127.0.0.1 → 10.200.0.x: MASQUERADE 없으면 pod가 127.0.0.1(자신의 lo)로 응답 시도 → hang
iptables -t nat -A POSTROUTING -s 127.0.0.0/8 -d 10.200.0.0/24 -j MASQUERADE
# pod → 외부 트래픽 MASQUERADE
iptables -t nat -A POSTROUTING -s 10.200.0.0/24 ! -o br0 -j MASQUERADE

echo ""
echo "=== 규칙 확인 ==="
iptables -t nat -L -n --line-numbers

echo ""
echo "=== ClusterIP 테스트 (9회) ==="
for i in $(seq 1 9); do curl -s http://10.96.0.1/; done

echo ""
echo "=== NodePort 테스트 (9회, 127.0.0.1:30080) ==="
# 주의: route_localnet=1 필요 (01-setup-namespaces.sh에서 설정)
for i in $(seq 1 9); do curl -s http://127.0.0.1:30080/; done
