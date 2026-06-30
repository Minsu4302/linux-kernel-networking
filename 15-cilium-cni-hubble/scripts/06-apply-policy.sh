#!/bin/bash
# CiliumNetworkPolicy L7 적용 및 검증 — lab-vm-01에서 실행
set -e

echo "=== CiliumNetworkPolicy (L7) 생성 ==="
echo "  대상: deathstar (org=empire, class=deathstar)"
echo "  허용: org=empire 소속 + POST /v1/request-landing 만"
echo "  차단: org=alliance(xwing), 다른 HTTP 메서드/경로"
echo ""

kubectl apply -f - <<'EOF'
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "rule1"
spec:
  description: "deathstar는 Empire 소속이 POST /v1/request-landing 요청만 허용"
  endpointSelector:
    matchLabels:
      org: empire
      class: deathstar
  ingress:
  - fromEndpoints:
    - matchLabels:
        org: empire
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: "POST"
          path: "/v1/request-landing"
EOF

echo ""
echo "=== 정책 확인 ==="
kubectl get ciliumnetworkpolicies
echo ""
kubectl describe ciliumnetworkpolicy rule1 | grep -A5 "Spec:"

sleep 3

echo ""
echo "================================================================"
echo "  연결성 테스트 (정책 적용 후)"
echo "================================================================"

TIEFIGHTER=$(kubectl get pod -l class=tiefighter -o jsonpath='{.items[0].metadata.name}')
XWING=$(kubectl get pod -l class=xwing -o jsonpath='{.items[0].metadata.name}')
SVC_IP=$(kubectl get service deathstar -o jsonpath='{.spec.clusterIP}')

echo ""
echo "[1] tiefighter → POST /v1/request-landing (허용 예상 ✅):"
kubectl exec "$TIEFIGHTER" -- \
  curl -s -o /dev/null -w "  HTTP %{http_code}\n" \
  -X POST "http://${SVC_IP}/v1/request-landing"

echo ""
echo "[2] tiefighter → PUT /v1/exhaust-port (차단 예상 ❌ — 경로 불일치):"
kubectl exec "$TIEFIGHTER" -- \
  curl -s -o /dev/null -w "  HTTP %{http_code}\n" \
  --max-time 3 -X PUT "http://${SVC_IP}/v1/exhaust-port" \
  || echo "  타임아웃 = DROP (정책 차단)"

echo ""
echo "[3] xwing → POST /v1/request-landing (차단 예상 ❌ — org=alliance):"
kubectl exec "$XWING" -- \
  curl -s -o /dev/null -w "  HTTP %{http_code}\n" \
  --max-time 3 -X POST "http://${SVC_IP}/v1/request-landing" \
  || echo "  타임아웃 = DROP (정책 차단)"

echo ""
echo "================================================================"
echo "  → 07-observe-hubble.sh 로 Hubble에서 플로우 확인하세요"
echo "================================================================"
