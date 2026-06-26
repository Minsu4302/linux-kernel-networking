#!/bin/bash
# 측정 결과 비교 출력 — lab-vm-01에서 실행
# 02-measure-latency.sh 를 각 단계마다 실행 완료 후 사용

echo "================================================================"
echo "  Network Policy 확장성 벤치마크 결과"
echo "================================================================"
printf "  %-20s %-15s %-15s\n" "조건" "avg RTT (ms)" "규칙 수"
printf "  %-20s %-15s %-15s\n" "----" "------------" "------"

declare -A RULE_COUNT
RULE_COUNT["baseline"]="0"
RULE_COUNT["iptables-100"]="100"
RULE_COUNT["iptables-1000"]="1000"
RULE_COUNT["iptables-5000"]="5000"
RULE_COUNT["ipset-5000"]="5000 (ipset)"

for label in baseline iptables-100 iptables-1000 iptables-5000 ipset-5000; do
    FILE="/tmp/latency_${label}.txt"
    RULES="${RULE_COUNT[$label]}"
    if [ -f "$FILE" ]; then
        RTT=$(cat "$FILE")
        printf "  %-20s %-15s %-15s\n" "$label" "$RTT" "$RULES"
    else
        printf "  %-20s %-15s %-15s\n" "$label" "(없음)" "$RULES"
    fi
done

echo "================================================================"
echo ""
echo "핵심 해석:"
echo "  - iptables: 규칙 수 증가 → RTT 선형 증가 (O(N) 탐색)"
echo "  - ipset:    규칙 5000개여도 RTT 거의 동일 (O(1) 해시)"
echo "  - Cilium:   BPF 맵으로 ipset과 동일한 O(1), 추가로 L7 정책 지원"
