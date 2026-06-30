#!/bin/bash
# K8s 클러스터 초기화 — 전체 3대 VM에서 순서대로 실행
# 순서: vm-02 → vm-03 → vm-01
set -e

echo "=== K8s 노드 초기화 (kubeadm reset) ==="
sudo kubeadm reset --force

echo ""
echo "=== CNI 설정 제거 ==="
sudo rm -rf /etc/cni/net.d
sudo rm -rf /var/lib/cni

echo ""
echo "=== iptables / ipvs 초기화 ==="
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X
sudo ipvsadm --clear 2>/dev/null || true

echo ""
echo "=== kubeconfig 제거 ==="
rm -rf "$HOME/.kube"

echo ""
echo "=== Cilium / Hubble CLI 제거 (vm-01만) ==="
sudo rm -f /usr/local/bin/cilium /usr/local/bin/hubble

echo ""
echo "=== BPF 마운트 해제 시도 ==="
sudo umount /sys/fs/bpf 2>/dev/null || true
sudo rm -rf /var/lib/cilium 2>/dev/null || true

echo ""
echo "✅ 초기화 완료 — 재실험 시 01-install-prerequisites.sh 부터 다시 실행"
