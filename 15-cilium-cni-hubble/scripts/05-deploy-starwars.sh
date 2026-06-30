#!/bin/bash
# Star Wars 데모 앱 배포 및 정책 적용 전 연결 테스트 — lab-vm-01에서 실행
set -e

DEMO_URL="https://raw.githubusercontent.com/cilium/cilium/1.15.5/examples/minikube/http-sw-app.yaml"

echo "=== Star Wars 데모 앱 배포 ==="
echo "  deathstar  : Galactic Empire의 우주전함 (80포트 HTTP 서버)"
echo "  tiefighter : Empire 전투기 (org=empire)"
echo "  xwing      : Alliance 전투기 (org=alliance)"
echo ""
kubectl apply -f "$DEMO_URL"

echo ""
echo "=== 파드 Ready 대기 ==="
kubectl rollout status deployment/deathstar --timeout=3m
echo ""
kubectl get pods -o wide
echo ""
kubectl get service deathstar

echo ""
echo "=== 연결성 테스트 (CiliumNetworkPolicy 적용 전) ==="
echo "  이 시점에는 모든 트래픽이 허용됨"
echo ""

TIEFIGHTER=$(kubectl get pod -l class=tiefighter -o jsonpath='{.items[0].metadata.name}')
XWING=$(kubectl get pod -l class=xwing -o jsonpath='{.items[0].metadata.name}')
SVC_IP=$(kubectl get service deathstar -o jsonpath='{.spec.clusterIP}')

echo "[1] tiefighter → POST /v1/request-landing"
kubectl exec "$TIEFIGHTER" -- curl -s -X POST "http://${SVC_IP}/v1/request-landing"
echo ""

echo ""
echo "[2] xwing → POST /v1/request-landing (정책 전: 허용됨)"
kubectl exec "$XWING" -- curl -s -X POST "http://${SVC_IP}/v1/request-landing"
echo ""

echo ""
echo "[3] tiefighter → PUT /v1/exhaust-port (정책 전: 허용됨)"
kubectl exec "$TIEFIGHTER" -- curl -s -X PUT "http://${SVC_IP}/v1/exhaust-port"
echo ""

echo ""
echo "=== 06-apply-policy.sh 로 L7 정책을 적용하세요 ==="
