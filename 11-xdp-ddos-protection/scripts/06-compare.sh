#!/bin/bash
# 3가지 조건의 CPU 사용률 비교 출력 — lab-vm-02에서 실행
# 02, 03, 04 스크립트 실행 완료 후 사용

echo "================================================================"
echo "  XDP DDoS 방어 벤치마크 결과 비교"
echo "================================================================"
printf "  %-20s %-10s %-10s %-10s %-10s\n" "조건" "%sys" "%softirq" "%idle" "사용률"
printf "  %-20s %-10s %-10s %-10s %-10s\n" "----" "----" "--------" "-----" "------"

while IFS=: read -r label file; do
    if [ -f "$file" ]; then
        awk -v label="$label" '/Average/ {
            printf "  %-20s %-10.1f %-10.1f %-10.1f %-10.1f\n",
            label, $4, $6, $12, 100-$12
        }' "$file"
    else
        printf "  %-20s (데이터 없음)\n" "$label"
    fi
done <<'EOF'
Baseline:/tmp/baseline_cpu.txt
iptables DROP:/tmp/iptables_cpu.txt
XDP DROP:/tmp/xdp_cpu.txt
EOF

echo "================================================================"
echo ""
echo "핵심 해석:"
echo "  - Baseline: ICMP 응답 생성 오버헤드로 CPU 가장 높음"
echo "  - iptables: netfilter 훅 통과 후 드롭 → 응답 없애 CPU 절감"
echo "  - XDP:      NIC 초입에서 드롭 (xdpgeneric: SKB 생성 후 드롭)"
echo "  - 프로덕션 native XDP는 SKB 생성 전 드롭 → 더 극적인 차이"
