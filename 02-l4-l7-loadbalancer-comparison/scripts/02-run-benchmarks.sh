#!/bin/bash
# IPVS / HAProxy L4 / HAProxy L7 / Nginx L7 를 같은 3개 백엔드로 순서대로 벤치마크한다.
# 사전 조건: 01-setup-backends.sh 로 백엔드 3대가 실행 중이어야 한다.
# 필요 패키지: ipvsadm, haproxy, nginx, wrk
set -e

WRK_OPTS="-t2 -c100 -d15s --latency"
LB_PORT="8080"
IPVS_VIP="10.96.0.100"

_wait_port() {
    local port=$1
    for i in $(seq 1 10); do
        ss -tlnp | grep -q ":${port}" && return 0
        sleep 0.5
    done
    echo "포트 $port 열기 실패" >&2
    exit 1
}

# ──────────────────────────────────────────────
echo ""
echo "=========================================="
echo "1/4  IPVS (커널 L4, NAT 모드)"
echo "=========================================="
sudo sysctl -w net.ipv4.conf.all.route_localnet=1 >/dev/null
sudo ip addr add "${IPVS_VIP}/32" dev lo 2>/dev/null || true
sudo ipvsadm -C
sudo ipvsadm -A -t "${IPVS_VIP}:80" -s rr
sudo ipvsadm -a -t "${IPVS_VIP}:80" -r 127.0.0.1:8081 -m
sudo ipvsadm -a -t "${IPVS_VIP}:80" -r 127.0.0.1:8082 -m
sudo ipvsadm -a -t "${IPVS_VIP}:80" -r 127.0.0.1:8083 -m
sleep 1
wrk $WRK_OPTS "http://${IPVS_VIP}:80/"
sudo ipvsadm -C
sudo ip addr del "${IPVS_VIP}/32" dev lo 2>/dev/null || true
sleep 2

# ──────────────────────────────────────────────
echo ""
echo "=========================================="
echo "2/4  HAProxy L4 (mode tcp)"
echo "=========================================="
cat > /tmp/lb-haproxy-l4.cfg << 'EOF'
global
    daemon
    maxconn 4096
defaults
    mode tcp
    timeout connect 5s
    timeout client  30s
    timeout server  30s
    # wrk 종료 후 HAProxy가 연결 드레인을 기다리지 않도록 즉시 종료
    hard-stop-after 1s
frontend f
    bind *:8080
    default_backend be
backend be
    balance roundrobin
    server b1 127.0.0.1:8081
    server b2 127.0.0.1:8082
    server b3 127.0.0.1:8083
EOF
sudo haproxy -f /tmp/lb-haproxy-l4.cfg -p /tmp/lb-haproxy.pid
_wait_port $LB_PORT
wrk $WRK_OPTS "http://127.0.0.1:${LB_PORT}/"
sudo kill -9 "$(cat /tmp/lb-haproxy.pid)" 2>/dev/null || true
sleep 1

# ──────────────────────────────────────────────
echo ""
echo "=========================================="
echo "3/4  HAProxy L7 (mode http)"
echo "=========================================="
cat > /tmp/lb-haproxy-l7.cfg << 'EOF'
global
    daemon
    maxconn 4096
defaults
    mode http
    timeout connect 5s
    timeout client  30s
    timeout server  30s
    hard-stop-after 1s
frontend f
    bind *:8080
    default_backend be
backend be
    balance roundrobin
    server b1 127.0.0.1:8081
    server b2 127.0.0.1:8082
    server b3 127.0.0.1:8083
EOF
sudo haproxy -f /tmp/lb-haproxy-l7.cfg -p /tmp/lb-haproxy.pid
_wait_port $LB_PORT
wrk $WRK_OPTS "http://127.0.0.1:${LB_PORT}/"
sudo kill -9 "$(cat /tmp/lb-haproxy.pid)" 2>/dev/null || true
sleep 1

# ──────────────────────────────────────────────
echo ""
echo "=========================================="
echo "4/4  Nginx L7 (upstream round-robin)"
echo "=========================================="
cat > /tmp/lb-nginx.cfg << 'EOF'
pid /tmp/lb-nginx.pid;
error_log /tmp/lb-nginx-err.log warn;
events { worker_connections 1024; }
http {
    access_log off;
    upstream be {
        server 127.0.0.1:8081;
        server 127.0.0.1:8082;
        server 127.0.0.1:8083;
    }
    server {
        listen 8080;
        location / { proxy_pass http://be; }
    }
}
EOF
sudo nginx -c /tmp/lb-nginx.cfg
_wait_port $LB_PORT
wrk $WRK_OPTS "http://127.0.0.1:${LB_PORT}/"
sudo kill -9 "$(cat /tmp/lb-nginx.pid)" 2>/dev/null || true
sleep 1

echo ""
echo "=== 전체 벤치마크 완료 ==="
