#!/bin/bash
# Hubble로 L7 플로우 관찰 — lab-vm-01에서 실행
set -e

echo "=== Hubble 포트 포워드 시작 ==="
cilium hubble port-forward &
PF_PID=$!
trap "kill $PF_PID 2>/dev/null || true" EXIT
sleep 3

echo ""
echo "=== Hubble 상태 확인 ==="
hubble status

echo ""
echo "================================================================"
echo "  테스트 트래픽 생성 + 실시간 플로우 관찰"
echo "================================================================"
echo ""

TIEFIGHTER=$(kubectl get pod -l class=tiefighter -o jsonpath='{.items[0].metadata.name}')
XWING=$(kubectl get pod -l class=xwing -o jsonpath='{.items[0].metadata.name}')
SVC_IP=$(kubectl get service deathstar -o jsonpath='{.spec.clusterIP}')

# Hubble 관찰 백그라운드 시작
hubble observe --follow --output json 2>/dev/null > /tmp/hubble-flows.json &
HUBBLE_PID=$!
sleep 1

echo "트래픽 생성 중..."
kubectl exec "$TIEFIGHTER" -- curl -s -X POST "http://${SVC_IP}/v1/request-landing" > /dev/null 2>&1 || true
kubectl exec "$TIEFIGHTER" -- curl -s -X PUT  "http://${SVC_IP}/v1/exhaust-port" --max-time 2 > /dev/null 2>&1 || true
kubectl exec "$XWING"      -- curl -s -X POST "http://${SVC_IP}/v1/request-landing" --max-time 2 > /dev/null 2>&1 || true
sleep 3

kill $HUBBLE_PID 2>/dev/null || true

echo ""
echo "=== 캡처된 L7 HTTP 플로우 ==="
if [ -s /tmp/hubble-flows.json ]; then
    python3 - <<'PYEOF'
import sys, json

flows = []
with open('/tmp/hubble-flows.json') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
            flow = obj.get('flow', {})
            l7 = flow.get('l7', {})
            if not l7:
                continue
            http = l7.get('http', {})
            if not http:
                continue
            verdict = flow.get('verdict', 'UNKNOWN')
            src_ns  = flow.get('source', {}).get('namespace', '')
            src_lbl = [l for l in flow.get('source', {}).get('labels', []) if 'class=' in l or 'org=' in l]
            dst_lbl = [l for l in flow.get('destination', {}).get('labels', []) if 'class=' in l]
            method  = http.get('method', '')
            url     = http.get('url', '')
            code    = http.get('code', '')
            mark    = '✅' if verdict == 'FORWARDED' else '❌'
            print(f"  {mark} {verdict:12s} | {method:6s} {url:30s} | src={src_lbl} | HTTP {code}")
        except Exception:
            pass
PYEOF
else
    echo "  (플로우 데이터 없음 — Hubble relay가 준비되지 않았을 수 있음)"
    echo ""
    echo "  hubble observe 직접 실행:"
    echo "    cilium hubble port-forward &"
    echo "    hubble observe --follow --type l7"
fi

echo ""
echo "=== 집계 통계 ==="
hubble observe --type l7 --last 50 2>/dev/null | tail -20 || echo "  (hubble port-forward가 종료된 경우 재실행 필요)"
