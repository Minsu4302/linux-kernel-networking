#!/bin/bash
# MSS Clamping 효과를 단계별로 관찰한다.
# lab-vm-01에서 실행. lab-vm-02에서 TCP 서버(포트 9999)가 실행 중이어야 한다.
set -e

SERVER_IP="192.168.100.2"  # vm-02 VXLAN IP (환경에 맞게 수정)
PORT=9999

observe_mss() {
    local label="$1"
    echo "  [$label] SYN/SYN-ACK MSS 캡처 중..."
    sudo tcpdump -i vxlan0 -n -v 'tcp[13] & 2 != 0' -l 2>/dev/null &
    local TCPDUMP_PID=$!
    sleep 1
    echo "테스트" | nc -w2 "$SERVER_IP" "$PORT" 2>/dev/null || true
    sleep 1
    kill "$TCPDUMP_PID"
    wait "$TCPDUMP_PID" 2>/dev/null || true
    echo ""
}

echo "=== MSS Clamping 단계별 데모 ==="
echo "VXLAN MTU=1410, 기본 MSS = 1410−40 = 1370"
echo ""

echo "--- 1단계: 기본 상태 (iptables 규칙 없음) ---"
observe_mss "기본"

echo "--- 2단계: --set-mss 500 (강제 축소) ---"
echo "  규칙 추가: iptables -t mangle -A OUTPUT ... -j TCPMSS --set-mss 500"
sudo iptables -t mangle -A OUTPUT -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 500
observe_mss "set-mss 500"
sudo iptables -t mangle -D OUTPUT -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 500
echo "  규칙 제거 완료"
echo ""

echo "--- 3단계: --clamp-mss-to-pmtu (Path MTU 자동 계산) ---"
echo "  규칙 추가: OUTPUT + FORWARD 체인에 --clamp-mss-to-pmtu"
sudo iptables -t mangle -A OUTPUT  -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
observe_mss "clamp-mss-to-pmtu"

echo "=== 결론 ==="
echo "  기본             : 양쪽 mss 1370"
echo "  --set-mss 500    : SYN=500, SYN-ACK=1370 → 실제 MSS=min(500,1370)=500"
echo "  --clamp-mss-to-pmtu: Path MTU(1410) 기반 → mss 1370 (자동 유지)"
echo ""
echo "실무: 오버레이/VPN 터널 추가로 MTU 줄었을 때 대용량 전송 단편화 방지"
echo "체인: FORWARD(포워딩 패킷), OUTPUT(로컬 생성 패킷) 모두 적용 필요"
echo ""
echo "cleanup.sh를 실행하면 남은 iptables 규칙을 제거합니다."
