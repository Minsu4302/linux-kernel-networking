#!/bin/bash
# Cilium + Hubble 설치 — lab-vm-01에서 실행
# kubeProxyReplacement=true: kube-proxy 완전 대체
set -e

CILIUM_VERSION="1.15.5"
IFACE=$(ip route | awk '/default/{print $5; exit}')
MY_IP=$(ip -4 addr show "$IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

echo "=== Cilium CLI 설치 ==="
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt 2>/dev/null || echo "v0.16.10")
echo "  버전: $CILIUM_CLI_VERSION"
curl -L --fail --silent --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-amd64.tar.gz"{,.sha256sum}
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
sudo tar xzC /usr/local/bin -f cilium-linux-amd64.tar.gz
rm cilium-linux-amd64.tar.gz cilium-linux-amd64.tar.gz.sha256sum
echo "  cilium CLI: $(cilium version --client 2>/dev/null | head -1)"

echo ""
echo "=== Hubble CLI 설치 ==="
HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt 2>/dev/null || echo "v0.13.3")
echo "  버전: $HUBBLE_VERSION"
curl -L --fail --silent --remote-name-all \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-amd64.tar.gz"{,.sha256sum}
sha256sum --check hubble-linux-amd64.tar.gz.sha256sum
sudo tar xzC /usr/local/bin -f hubble-linux-amd64.tar.gz
rm hubble-linux-amd64.tar.gz hubble-linux-amd64.tar.gz.sha256sum
echo "  hubble CLI: $(hubble version 2>/dev/null | head -1)"

echo ""
echo "=== Cilium 설치 (kube-proxy 대체 + Hubble 활성화) ==="
echo "  Cilium 버전  : $CILIUM_VERSION"
echo "  API Server   : ${MY_IP}:6443"
echo "  kubeProxyReplacement=true"
echo ""
cilium install \
  --version "$CILIUM_VERSION" \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost="${MY_IP}" \
  --set k8sServicePort=6443 \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true \
  --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,http}"

echo ""
echo "=== Cilium 준비 완료 대기 (최대 5분) ==="
cilium status --wait --wait-duration 5m

echo ""
echo "=== 최종 상태 ==="
kubectl get nodes
echo ""
kubectl get pods -n kube-system -l k8s-app=cilium
echo ""
cilium status | grep -E "KubeProxyReplacement|Hubble"
