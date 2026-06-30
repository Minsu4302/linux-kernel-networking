#!/bin/bash
# K8s 클러스터 초기화 — lab-vm-01(Control Plane)에서 실행
# kube-proxy를 건너뛰어 Cilium이 대체하도록 설정
set -e

IFACE=$(ip route | awk '/default/{print $5; exit}')
MY_IP=$(ip -4 addr show "$IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
POD_CIDR="10.244.0.0/16"

echo "=== K8s 클러스터 초기화 ==="
echo "  Control Plane IP : $MY_IP"
echo "  Pod CIDR         : $POD_CIDR"
echo "  kube-proxy       : 건너뜀 (Cilium이 eBPF로 대체)"
echo ""

sudo kubeadm init \
  --pod-network-cidr="$POD_CIDR" \
  --apiserver-advertise-address="$MY_IP" \
  --skip-phases=addon/kube-proxy

echo ""
echo "=== kubeconfig 설정 ==="
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"

echo ""
echo "=== Worker Join 명령 생성 ==="
echo "  아래 명령을 vm-02, vm-03에서 실행하세요:"
echo "  ─────────────────────────────────────────"
kubeadm token create --print-join-command | tee /tmp/kubeadm-join.txt
echo "  ─────────────────────────────────────────"
echo "  (명령이 /tmp/kubeadm-join.txt 에도 저장됨)"

echo ""
echo "=== 현재 노드 상태 (Cilium 설치 전이라 NotReady 정상) ==="
kubectl get nodes
