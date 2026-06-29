# 14. 고가용성(HA) & Failover

## 왜 이 주제인가

프로덕션 서비스에서 단일 서버는 단일 장애점(SPOF)이 된다. Keepalived + VRRP는 GCP/AWS의 Managed Load Balancer 이전에, 또는 온프레미스에서 두 서버가 하나의 VIP(Virtual IP)를 공유하며 자동 Failover를 구현하는 표준 방법이다. nginx나 HAProxy 앞에 Keepalived를 두는 패턴은 여전히 실무에서 광범위하게 사용된다. 이 주제에서는 VRRP 상태 머신을 직접 확인하고, Primary 장애 시 Backup이 서비스를 이어받는 데 걸리는 시간을 밀리초 단위로 측정한다.

---

## 아키텍처

```
[lab-vm-01] 클라이언트 / 모니터링
10.178.0.2
  │
  ├─ curl http://10.178.0.3:8080  ─── [lab-vm-02] Primary (MASTER)
  │                                    Keepalived priority 100
  │                                    nginx 동작 중 (notify_master)
  │
  └─ curl http://10.178.0.4:8080  ─── [lab-vm-03] Backup (BACKUP)
                                       Keepalived priority 90
                                       nginx 중지 상태 (notify_backup)

VRRP 유니캐스트: vm-02 ↔ vm-03 (1초 간격 헬스체크)
Failover: vm-02 장애 → vm-03이 MASTER 전환 → nginx 시작
```

### VRRP 상태 머신

```
          ┌──────────────────────────────────┐
          │         VRRP 상태 전환           │
          └──────────────────────────────────┘

시작 ──→ [BACKUP]
            │ advert_int 동안 MASTER 광고 수신 없음
            ▼
         [MASTER] ←── 우선순위 높은 쪽이 선출
            │ 장애 / 네트워크 단절
            ▼
         [FAULT] ──→ [BACKUP]
```

> **GCP 제약**: VRRP는 기본적으로 멀티캐스트(224.0.0.18)를 사용하지만 GCP VPC는 멀티캐스트를 차단. **유니캐스트 VRRP** 설정 필수.

---

## 실습 환경

| VM | 물리 IP | 역할 |
|----|---------|------|
| lab-vm-01 | 10.178.0.2 | 클라이언트, Failover 시간 측정 |
| lab-vm-02 | 10.178.0.3 | Primary (Keepalived MASTER) |
| lab-vm-03 | 10.178.0.4 | Backup (Keepalived BACKUP) |

---

## 실험 방법

1. vm-02, vm-03에 Keepalived + nginx 설치
2. VRRP 설정 (유니캐스트) — vm-02: priority 100, vm-03: priority 90
3. `notify_master` / `notify_backup` 스크립트로 nginx 자동 시작/중지
4. vm-01에서 두 VM을 동시에 폴링하는 모니터링 시작
5. vm-02 Keepalived 중지 → Failover 시간 기록

---

## 스크립트 목록

| 파일 | 설명 | 실행 노드 |
|------|------|---------|
| `scripts/01-install.sh` | Keepalived + nginx 설치 | vm-02, vm-03 |
| `scripts/02-setup-primary.sh` | Keepalived MASTER 설정 | vm-02 |
| `scripts/03-setup-backup.sh` | Keepalived BACKUP 설정 | vm-03 |
| `scripts/04-monitor.sh` | 두 VM 동시 폴링, 전환 감지 | vm-01 |
| `scripts/05-failover-test.sh` | Failover 시간 정밀 측정 | vm-01 |
| `scripts/06-cleanup.sh` | Keepalived 중지 및 설정 제거 | vm-02, vm-03 |

---

## 핵심 개념

### VRRP (Virtual Router Redundancy Protocol)

```
VRRP Advertisement (unicast, 1초 간격)
  vm-02(MASTER) ──────────────────────→ vm-03(BACKUP)
                                              │
                          advert_int × 3 동안 수신 없음
                                              ▼
                                       MASTER 전환
                                       notify_master 실행
                                       nginx 시작
```

### Keepalived 설정 핵심 파라미터

| 파라미터 | 의미 | 이 실습 |
|----------|------|---------|
| `advert_int` | VRRP 광고 주기 (초) | 1초 |
| `priority` | 높을수록 MASTER 선호 | Primary 100, Backup 90 |
| `virtual_router_id` | VRRP 그룹 ID | 51 |
| `unicast_src_ip` | 유니캐스트 VRRP 송신 IP | 각 VM의 실제 IP |
| `unicast_peer` | 유니캐스트 VRRP 수신 대상 | 상대방 VM IP |

### Failover 타이밍

```
vm-02 장애 발생
  │
  ├── VRRP advert_int 동안 광고 없음 감지: ~1-3초
  │   (advert_int=1, dead_int 기본=3×advert_int=3초)
  │
  ├── vm-03: MASTER 상태로 전환
  │
  ├── notify_master 스크립트 실행: ~0.1초
  │
  └── nginx 시작 + 서비스 응답 가능: ~0.2초

총 Failover 시간: 약 2~4초
```

---

## 참고

- [Keepalived 공식 문서](https://www.keepalived.org/manpage.html)
- [VRRP RFC 5798](https://datatracker.ietf.org/doc/html/rfc5798)
- [GCP에서 Keepalived 사용](https://cloud.google.com/solutions/sql-server/sql-server-ha-using-keepalived)
