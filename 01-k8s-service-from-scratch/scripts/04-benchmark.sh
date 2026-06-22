#!/bin/bash
# iptables vs IPVS 규칙 관리 성능 비교 벤치마크
#
# 측정 항목:
#   iptables-restore: N개 서비스(서비스당 DNAT 3규칙) 일괄 로드 시간
#   iptables-save:    N개 규칙 덤프 시간 (rule scan 오버헤드 간접 측정)
#   ipvsadm -R:       N개 가상 서비스 일괄 추가 시간
#   ipvsadm -Ln:      N개 가상 서비스 목록 출력 시간
#
# 실측값 (GCP e2-standard-2, 커널 6.8.0-1060-gcp, 2026-06-22):
#   서비스수  iptables-restore  iptables-save  ipvsadm-add  ipvsadm-list
#   1         33ms              28ms           22ms         19ms
#   100       44ms              34ms           43ms         27ms
#   1000      168ms             105ms          255ms        88ms
#   5000      728ms             408ms          1260ms       366ms
#
# 주의: 이 벤치마크는 control-plane(규칙 관리) 성능을 측정.
#       data-plane(패킷 포워딩) 성능 차이(iptables O(N) vs IPVS O(1))는
#       별도 네트워크 부하 테스트 도구(hping3, wrk 등) 필요.

set -e

gen_ipt() {
    local N=$1
    echo "*nat"
    echo ":PREROUTING ACCEPT [0:0]"
    for i in $(seq 0 $((N-1))); do
        A=$(( i / 254 ))
        B=$(( i % 254 + 1 ))
        echo "-A PREROUTING -d 10.96.${A}.${B} -p tcp --dport 80 -m statistic --mode random --probability 0.33333 -j DNAT --to-destination 10.200.0.10:8080"
        echo "-A PREROUTING -d 10.96.${A}.${B} -p tcp --dport 80 -m statistic --mode random --probability 0.50000 -j DNAT --to-destination 10.200.0.11:8080"
        echo "-A PREROUTING -d 10.96.${A}.${B} -p tcp --dport 80 -j DNAT --to-destination 10.200.0.12:8080"
    done
    echo "COMMIT"
}

gen_ipvs() {
    local N=$1
    for i in $(seq 0 $((N-1))); do
        A=$(( i / 254 ))
        B=$(( i % 254 + 1 ))
        echo "-A -t 10.96.${A}.${B}:80 -s rr"
        echo "-a -t 10.96.${A}.${B}:80 -r 10.200.0.10:8080 -m"
        echo "-a -t 10.96.${A}.${B}:80 -r 10.200.0.11:8080 -m"
        echo "-a -t 10.96.${A}.${B}:80 -r 10.200.0.12:8080 -m"
    done
}

echo "================================================="
echo "   iptables vs IPVS 성능 비교 (서비스 수 증가)"
echo "================================================="
echo ""
printf "%-8s | %-22s %-20s\n" "서비스수" "iptables-restore(ms)" "iptables-save(ms)"
echo "---------|----------------------|--------------------"

for N in 1 100 1000 5000; do
    iptables -t nat -F PREROUTING 2>/dev/null
    RULES=$(gen_ipt $N)

    T1=$(date +%s%N)
    echo "$RULES" | iptables-restore --noflush
    T2=$(date +%s%N)
    R_MS=$(( (T2-T1)/1000000 ))

    T3=$(date +%s%N)
    iptables-save > /dev/null
    T4=$(date +%s%N)
    S_MS=$(( (T4-T3)/1000000 ))

    printf "%-8s | %-22s %-20s\n" "$N" "${R_MS}ms" "${S_MS}ms"
done

iptables -t nat -F PREROUTING 2>/dev/null

echo ""
printf "%-8s | %-22s %-20s\n" "서비스수" "ipvsadm-add(ms)" "ipvsadm-list(ms)"
echo "---------|----------------------|--------------------"

for N in 1 100 1000 5000; do
    ipvsadm -C 2>/dev/null

    T1=$(date +%s%N)
    gen_ipvs $N | ipvsadm -R
    T2=$(date +%s%N)
    A_MS=$(( (T2-T1)/1000000 ))

    T3=$(date +%s%N)
    ipvsadm -Ln > /dev/null
    T4=$(date +%s%N)
    L_MS=$(( (T4-T3)/1000000 ))

    printf "%-8s | %-22s %-20s\n" "$N" "${A_MS}ms" "${L_MS}ms"
done

ipvsadm -C 2>/dev/null
iptables -t nat -F PREROUTING 2>/dev/null
echo ""
echo "벤치마크 완료"
