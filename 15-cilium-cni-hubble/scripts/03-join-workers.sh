#!/bin/bash
# Worker 노드 Join — lab-vm-02, lab-vm-03에서 실행
#
# 사용법:
#   vm-01의 02-init-cluster.sh 출력에서 'kubeadm join ...' 명령을 복사해 직접 실행하거나,
#   환경 변수로 지정:
#
#   MASTER_IP=10.178.0.2 TOKEN=<token> HASH=<sha256:hash> sudo -E bash 03-join-workers.sh

set -e

if [ -z "$MASTER_IP" ] || [ -z "$TOKEN" ] || [ -z "$HASH" ]; then
    echo "❌ 환경변수 미설정"
    echo ""
    echo "  방법 1 (권장): vm-01에서 출력된 'kubeadm join ...' 명령을 그대로 복사해 실행"
    echo "  방법 2: 환경변수 지정 후 실행"
    echo "    export MASTER_IP=10.178.0.2"
    echo "    export TOKEN=<vm-01 출력값>"
    echo "    export HASH=sha256:<vm-01 출력값>"
    echo "    sudo -E bash 03-join-workers.sh"
    exit 1
fi

echo "=== Worker 노드 Join ==="
echo "  Master: ${MASTER_IP}:6443"
echo "  Token : $TOKEN"

sudo kubeadm join "${MASTER_IP}:6443" \
    --token "$TOKEN" \
    --discovery-token-ca-cert-hash "$HASH"

echo ""
echo "=== Join 완료 ==="
echo "  vm-01에서 'kubectl get nodes' 로 확인하세요."
