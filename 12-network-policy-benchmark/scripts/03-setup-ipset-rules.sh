#!/bin/bash
# ipset 방식으로 동일 IP 집합 적용 — lab-vm-02에서 실행
# 사용법: ./03-setup-ipset-rules.sh <ip_count>
set -e

COUNT=${1:-5000}
ALLOW_IP="10.178.0.2"

echo "=== ipset 방식 설정: ${COUNT}개 IP ==="

# 기존 iptables 규칙 정리
sudo iptables -F INPUT 2>/dev/null || true

# 기존 ipset 정리
sudo ipset destroy dummy_ips 2>/dev/null || true
sudo ipset destroy allow_ips 2>/dev/null || true

# dummy_ips: 실제로 오지 않는 IP 5000개
echo "  dummy_ips 생성 중 (${COUNT}개)..."
sudo ipset create dummy_ips hash:ip
for i in $(seq 1 "$COUNT"); do
    A=$(( (i / 256) % 256 ))
    B=$(( i % 256 ))
    sudo ipset add dummy_ips "192.168.${A}.${B}"
done

# allow_ips: 실제 허용 IP
sudo ipset create allow_ips hash:ip
sudo ipset add allow_ips "$ALLOW_IP"

# iptables 규칙: 2개만 사용 (O(1) 조회)
sudo iptables -A INPUT -m set --match-set dummy_ips src -j ACCEPT
sudo iptables -A INPUT -m set --match-set allow_ips src -j ACCEPT

echo "  설정 완료"
echo ""
echo "=== ipset 상태 ==="
sudo ipset list dummy_ips | head -5
echo "  dummy_ips 총 항목: $(sudo ipset list dummy_ips | grep -c 'Members' -A 99999 | tail -n +2 | grep -c '.'  || sudo ipset list dummy_ips | tail -n +9 | wc -l)"
echo ""
echo "=== iptables 규칙 (2개만 사용) ==="
sudo iptables -L INPUT -n --line-numbers
