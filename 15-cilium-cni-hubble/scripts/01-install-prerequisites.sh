#!/bin/bash
# K8s + Cilium 실습 사전 준비 — 3대 VM 모두 실행
set -e

echo "=== XFRM 잔재 제거 (Topic 10 strongSwan 부작용) ==="
sudo systemctl stop strongswan 2>/dev/null || true
sudo ip xfrm policy flush 2>/dev/null || true
sudo ip xfrm state flush 2>/dev/null || true
echo "  XFRM 초기화 완료"

echo ""
echo "=== 스왑 비활성화 (kubeadm 요구사항) ==="
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab 2>/dev/null || true

echo ""
echo "=== 커널 모듈 로드 ==="
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
echo "  overlay, br_netfilter 로드 완료"

echo ""
echo "=== sysctl 설정 (브릿지 트래픽 iptables 통과) ==="
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system > /dev/null
echo "  sysctl 적용 완료"

echo ""
echo "=== containerd 설치 (Docker apt 저장소) ==="
sudo apt-get update -y -q
sudo apt-get install -y -q ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y -q
sudo apt-get install -y -q containerd.io

echo ""
echo "=== containerd SystemdCgroup 활성화 ==="
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
echo "  containerd 버전: $(containerd --version)"

echo ""
echo "=== kubeadm / kubelet / kubectl 설치 (K8s 1.30) ==="
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
sudo apt-get update -y -q
sudo apt-get install -y -q kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo ""
echo "=== 설치 완료 ==="
echo "  $(kubeadm version --output=short)"
echo "  $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
echo "  kubelet: $(kubelet --version)"
