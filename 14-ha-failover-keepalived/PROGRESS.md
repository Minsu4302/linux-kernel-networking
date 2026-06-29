# PROGRESS: 고가용성(HA) & Failover

## 진행 로그

### 2026-06-29

**한 일**
- Keepalived + nginx 설치 및 VRRP 유니캐스트 설정 (vm-02: MASTER, vm-03: BACKUP)
- GCP 환경 제약 4가지 해결
- VRRP Failover 시나리오 실행 및 로그 기반 수렴 시간 기록

**실험 결과**

| 측정 항목 | 결과 |
|-----------|------|
| VRRP Dead Interval 이론 수렴 | **~3초** (advert_int=1s × 3) |
| Graceful Shutdown 수렴 | 즉시 (priority=0 광고 → 피어 즉각 전환) |
| vm-01 서비스 전환 감지 (Backup 이미 MASTER) | **22ms** |
| Hold Timer 설정 | advert_int=1s, dead_interval=3s |

**VRRP 상태 전환 로그 (vm-03)**

```
10:36:54 → vm-03 MASTER (초기 선출)
10:38:25 → vm-02 재시작, priority 100 advert 수신 → vm-03 BACKUP
10:39:00 → vm-02 keepalived 중지 → vm-03 MASTER 재전환 (35초: 여러 재시작 시도 포함)
10:40:10 → vm-01 측정 시 vm-03 nginx 이미 구동 → 22ms 감지
```

**배운 것 (TIL)**
- **VRRP Dead Interval**: Backup은 `dead_interval = 3 × advert_int + skew_time` 동안 MASTER 광고 없으면 스스로 MASTER 전환. advert_int=1이면 ~3초
- **Graceful Shutdown**: `systemctl stop keepalived` → VRRP priority=0 광고 전송 → 피어 즉각 MASTER 전환 (BGP CEASE NOTIFICATION과 동일한 원리)
- **Hard Failure**: 링크 단절 / kill -9 → Dead Interval 3초 대기 후 수렴
- **GCP VRRP 제약**: 기본 방화벽이 IP protocol 112(VRRP) 차단 → `allow-vrrp` 규칙 직접 추가 필요
- **GCP 방화벽 targetTags**: `default-allow-http`, `default-allow-https`는 `http-server` 태그 없으면 미적용. 태그 없는 VM은 접근 불가
- **XFRM 잔재**: 이전 주제(IPsec) strongSwan이 VM 재시작마다 XFRM 정책 자동 복원 → 모든 TCP 연결 차단. 매 실습 시작 시 `ip xfrm policy flush` 필수
- **Keepalived notify 스크립트**: `notify_master` / `notify_backup` / `notify_fault` 를 활용해 서비스를 자동 시작/중지. 실제 프로덕션에서 HAProxy, Nginx, PostgreSQL 등에 동일하게 적용

**트러블슈팅**

| 증상 | 원인 | 해결 |
|------|------|------|
| 두 VM 모두 MASTER (split-brain) | GCP가 VRRP protocol 112 차단 → 유니캐스트 광고 미전달 | `gcloud compute firewall-rules create allow-vrrp --allow=112` |
| vm-01 → vm-02 TCP 연결 timeout | Topic 10 strongSwan XFRM 정책 잔재 | `sudo ip xfrm policy flush; sudo ip xfrm state flush` |
| curl port 8080 timeout | GCP `allow-8080` 규칙이 있음에도 차단 (원인 불명) | nginx 포트를 80으로 변경 후 `http-server` 태그 적용 |
| failover 스크립트가 "Primary 아직 DOWN" | nginx port 8080로 고정, 스크립트와 불일치 | 스크립트 포트를 80으로 수정 |
| keepalived stop 후 nginx 계속 동작 | nginx는 keepalived와 별개 서비스 | `systemctl stop keepalived nginx` 동시 실행 |

---

## 학습 키워드 누적 정리

- `Keepalived` — VRRP/LVS 기반 HA 데몬
- `VRRP (Virtual Router Redundancy Protocol)` — VIP를 공유하는 MASTER/BACKUP 선출 프로토콜
- `virtual_router_id` — VRRP 그룹 식별자 (같은 네트워크에서 고유해야 함)
- `advert_int` — VRRP 광고 주기 (초), MASTER가 피어에게 전송
- `dead_interval = 3 × advert_int + skew_time` — BACKUP이 MASTER 전환하는 타이머
- `priority` — 높을수록 MASTER 선호 (Primary 100, Backup 90)
- `unicast_src_ip / unicast_peer` — 멀티캐스트 대신 유니캐스트 VRRP 설정 (GCP 필수)
- `auth_type PASS` — VRRP 광고 인증 (8자 이내 패스워드)
- `notify_master / notify_backup / notify_fault` — 상태 전환 시 실행할 스크립트 훅
- `IP protocol 112` — VRRP 프로토콜 번호 (TCP/UDP 아님)
- `GCP targetTags` — 방화벽 규칙을 특정 VM에만 적용하는 태그 (http-server, https-server 등)

## 막혔던 점 / 다음에 더 파볼 것

- BFD(Bidirectional Forwarding Detection) 연동으로 sub-second 수렴 구현
- Keepalived + HAProxy 연동으로 실제 L4 로드밸런서 HA 구현
- GCP Managed Instance Group + Health Check vs Keepalived 비교
