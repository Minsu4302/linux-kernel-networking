#!/bin/bash
# IPVS로 K8s ClusterIP / NodePort 재현
#
# 전제: 01-setup-namespaces.sh 실행 완료
# iptables DNAT 규칙 대신 IPVS 가상 서버를 사용해 동일한 부하분산 구현
#
# IPVS NAT 모드(-m): director가 패킷의 dst를 real server IP로 변환
# 스케줄러: rr(round-robin) — iptables statistic과 달리 완전한 순환 보장
#
# 호스트 내부 IP: 자동 감지 (ens4 인터페이스 기준)
# 주의: 하드코딩된 IP가 있다면 아래 HOST_IP 라인을 수동 수정

set -e

HOST_IP=$(ip route get 8.8.8.8 | grep -oP 'src \K[\d.]+')
echo "Host IP: $HOST_IP (NodePort VIP로 사용)"

echo "=== iptables DNAT 규칙 제거 (MASQUERADE는 유지) ==="
iptables -t nat -F OUTPUT  2>/dev/null || true
iptables -t nat -F PREROUTING 2>/dev/null || true
iptables -t nat -F POSTROUTING 2>/dev/null || true

echo "=== POSTROUTING MASQUERADE 복원 (IPVS return 트래픽 필요) ==="
iptables -t nat -A POSTROUTING -s 127.0.0.0/8 -d 10.200.0.0/24 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.200.0.0/24 ! -o br0 -j MASQUERADE

echo "=== ClusterIP(10.96.0.1/32) lo에 등록 확인 ==="
ip addr add 10.96.0.1/32 dev lo 2>/dev/null || echo "(이미 존재)"

echo "=== IPVS 기존 설정 초기화 ==="
ipvsadm -C

echo "=== IPVS Virtual Service 설정 ==="
# ClusterIP: 10.96.0.1:80 → rr 스케줄러
ipvsadm -A -t 10.96.0.1:80 -s rr
ipvsadm -a -t 10.96.0.1:80 -r 10.200.0.10:8080 -m
ipvsadm -a -t 10.96.0.1:80 -r 10.200.0.11:8080 -m
ipvsadm -a -t 10.96.0.1:80 -r 10.200.0.12:8080 -m

# NodePort: 호스트 내부 IP:30080 → rr 스케줄러
ipvsadm -A -t ${HOST_IP}:30080 -s rr
ipvsadm -a -t ${HOST_IP}:30080 -r 10.200.0.10:8080 -m
ipvsadm -a -t ${HOST_IP}:30080 -r 10.200.0.11:8080 -m
ipvsadm -a -t ${HOST_IP}:30080 -r 10.200.0.12:8080 -m

echo ""
echo "=== IPVS 설정 확인 ==="
ipvsadm -Ln

echo ""
echo "=== ClusterIP 테스트 (9회) ==="
for i in $(seq 1 9); do curl -s http://10.96.0.1/; done

echo ""
echo "=== NodePort 테스트 (9회, ${HOST_IP}:30080) ==="
for i in $(seq 1 9); do curl -s http://${HOST_IP}:30080/; done
