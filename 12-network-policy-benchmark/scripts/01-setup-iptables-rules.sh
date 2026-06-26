#!/bin/bash
# dummy iptables ACCEPT 규칙 N개 생성 — lab-vm-02에서 실행
# 사용법: ./01-setup-iptables-rules.sh <rule_count>
# 예시:   ./01-setup-iptables-rules.sh 1000
set -e

COUNT=${1:-1000}
ALLOW_IP="10.178.0.2"   # lab-vm-01 (실제 허용할 IP)

echo "=== iptables dummy 규칙 ${COUNT}개 삽입 ==="

# 기존 규칙 정리
sudo iptables -F INPUT 2>/dev/null || true

# dummy ACCEPT 규칙 N개: 192.168.x.y 대역 (실제로 오지 않는 IP)
echo "  더미 규칙 삽입 중..."
for i in $(seq 1 "$COUNT"); do
    A=$(( (i / 256) % 256 ))
    B=$(( i % 256 ))
    sudo iptables -A INPUT -s "192.168.${A}.${B}" -j ACCEPT
done

# 실제 허용 규칙: 맨 끝에 추가 (최악의 경우를 시뮬레이션)
sudo iptables -A INPUT -s "$ALLOW_IP" -j ACCEPT

echo "  삽입 완료"
echo ""
echo "=== 현재 INPUT 규칙 수 ==="
sudo iptables -L INPUT --line-numbers -n | tail -5
echo "  총 규칙 수: $(sudo iptables -L INPUT -n | grep -c 'ACCEPT')"
