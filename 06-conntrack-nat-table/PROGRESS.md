# PROGRESS: Conntrack & NAT 테이블 한계

## 진행 로그

### 2026-06-23

**한 일**
- `conntrack -L`로 실제 테이블 관찰 (SSH, GCP 메타데이터, 외부 ICMP 스캐너, DNS 포함)
- network namespace + veth pair 구성 후 REDIRECT(DNAT) 적용, conntrack NAT 추적 엔트리 확인
- `nf_conntrack_max=64`로 축소 후 100개 연결 시도 → 59개 성공, 테이블 full 후 silent drop 재현
- `dmesg`에서 "nf_conntrack: table full, dropping packet" 확인
- `timeout_established` 432000→1800, `timeout_time_wait` 120→30 튜닝 적용

**배운 것 (TIL)**
- conntrack은 **양방향을 하나의 엔트리**로 관리: 원본방향 + 응답방향을 한 줄에 저장
- DNAT 엔트리의 응답방향 `sport=실제포트`가 포트 변환 정보를 담음. conntrack이 이걸 보고 응답 패킷을 원본 포트로 복원해 클라이언트에 전달
- 테이블 full 시 드롭 방식이 **RST가 아닌 silent drop** → 클라이언트 입장에서 타임아웃만 보임. 실제 장애에서 원인 파악이 가장 어려운 이유
- `timeout_established` 기본값이 **5일(432000초)**이어서 앱이 FIN/RST 없이 끊어지면 5일간 슬롯 점유
- 연결 흐름 중 일부가 실패 후 다시 성공한 이유: HTTP 서버가 요청 처리 후 연결을 닫아 TIME_WAIT 엔트리가 만료되며 빈 슬롯 생성
- `nf_conntrack_buckets`: 해시 버킷 수. max와 1:1이면 해시 충돌 최소화(O(1) 조회), 메모리 더 사용

**트러블슈팅**

| 증상 | 원인 | 해결 |
|------|------|------|
| 없음 (순조롭게 진행) | - | - |

---

## 학습 키워드 누적 정리

- `conntrack -L` — 전체 테이블 출력. 각 엔트리: 프로토콜, TTL, 상태, 원본방향, 응답방향
- `conntrack -C` — 현재 엔트리 수
- `/proc/sys/net/netfilter/nf_conntrack_count` — 실시간 카운트 (watch -n1 조합)
- `ASSURED` 플래그 — 양방향 트래픽 확인 완료. 연결이 살아있는 한 TTL 지속 리셋
- `NEW` → `ESTABLISHED` → `TIME_WAIT` — TCP conntrack 상태 전이
- `nf_conntrack_max` — 초과 시 SYN silent drop. `dmesg`에 "table full" 기록
- `nf_conntrack_buckets` — 해시 테이블 버킷 수. 큰 값 = 빠른 조회, 많은 메모리
- `timeout_established=432000(5일)` — 좀비 연결의 주범. 실무에서는 1800(30분) 권장
- `timeout_time_wait=120(2분)` — 실무에서는 30~60초로 줄이면 슬롯 재활용 빠름
- K8s: kube-proxy iptables 모드 → ClusterIP DNAT가 conntrack 의존 → 고트래픽 환경에서 테이블 고갈 주의

## 막혔던 점 / 다음에 더 파볼 것

- 이번 실습에서 외부에서 들어오는 ICMP 스캐너 패킷이 많아(10개 이상) 인터넷에 노출된 VM에 보안 그룹 없으면 conntrack 엔트리를 지속적으로 채운다는 점 확인. 실무에서는 GFW/방화벽으로 차단하거나 `nf_conntrack_icmp_timeout`을 줄이는 것이 권장됨
- K8s 환경에서 conntrack 고갈 시 `kubectl top node`나 `metrics-server`로는 원인이 안 보임. `node_nf_conntrack_entries` Prometheus 메트릭 수집이 필수
- `conntrack -E` (event monitor)로 연결 생성/제거 실시간 스트림 확인 미시도 → 추후 실습 여지
