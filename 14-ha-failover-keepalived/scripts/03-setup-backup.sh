#!/bin/bash
# Keepalived BACKUP 설정 — lab-vm-03에서 실행
set -e

MY_IP="10.178.0.4"
PEER_IP="10.178.0.3"
IFACE=$(ip route | awk '/default/{print $5; exit}')

echo "=== Keepalived BACKUP 설정 ==="
echo "  내 IP: $MY_IP, 피어 IP: $PEER_IP, 인터페이스: $IFACE"

# nginx 응답 페이지
sudo bash -c 'cat > /var/www/html/index.html' <<'HTML'
<!DOCTYPE html>
<html><body>
<h1>BACKUP (vm-03) - MASTER</h1>
<p>Keepalived HA - Backup Node (Failover Active)</p>
</body></html>
HTML

# nginx 포트 8080 설정
sudo bash -c 'cat > /etc/nginx/sites-available/default' <<'NGINX'
server {
    listen 80 default_server;
    root /var/www/html;
    index index.html;
}
NGINX

# notify 스크립트
sudo bash -c 'cat > /etc/keepalived/notify.sh' <<'NOTIFY'
#!/bin/bash
STATE=$1
logger "Keepalived notify: transitioning to $STATE"
case $STATE in
    master)
        systemctl start nginx
        logger "Keepalived: nginx started (MASTER)"
        ;;
    backup|fault)
        systemctl stop nginx
        logger "Keepalived: nginx stopped ($STATE)"
        ;;
esac
NOTIFY
sudo chmod +x /etc/keepalived/notify.sh

# Keepalived 설정 (Backup은 state BACKUP, priority 90)
sudo bash -c "cat > /etc/keepalived/keepalived.conf" <<CONF
global_defs {
    router_id vm03_backup
    script_user root
    enable_script_security
}

vrrp_instance VI_1 {
    state BACKUP
    interface $IFACE
    virtual_router_id 51
    priority 90
    advert_int 1

    unicast_src_ip $MY_IP
    unicast_peer {
        $PEER_IP
    }

    authentication {
        auth_type PASS
        auth_pass ha_lab_2026
    }

    notify_master "/etc/keepalived/notify.sh master"
    notify_backup "/etc/keepalived/notify.sh backup"
    notify_fault  "/etc/keepalived/notify.sh fault"
}
CONF

sudo systemctl restart keepalived
sudo systemctl enable keepalived

echo ""
echo "=== 설정 완료 ==="
sudo systemctl status keepalived --no-pager | grep -E "Active|State"
sleep 2
sudo journalctl -u keepalived --since "10 seconds ago" --no-pager | tail -5
