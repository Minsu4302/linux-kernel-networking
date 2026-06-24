# PROGRESS: TCP 커널 파라미터 튜닝

## 진행 로그

### 2026-06-24

**한 일**
- 초기 sysctl 값 확인 (somaxconn=4096, tcp_tw_reuse=2, tcp_fin_timeout=60, 포트 범위 32768-60999)
- somaxconn=5로 축소 후 50개 동시 연결: `TcpExtListenOverflows` +46 드롭, ss -lnt에서 Recv-Q=4 ≥ Send-Q=3 확인
- 50개 curl 반복으로 TIME_WAIT 누적 확인
- ip_local_port_range=10000-10099 (100개)로 축소 후 150개 연결 → 성공 0, 실패 150 (포트 고갈 재현)
- 권장 sysctl 값 적용 및 복원

**배운 것 (TIL)**
- `connect()`는 3-way handshake 완료 시 반환 → accept queue에서 대기 중인 연결도 클라이언트 입장에선 "성공"으로 보임. accept queue 오버플로는 그 이후에 발생하는 ACK 드롭 형태
- `ss -lnt`의 `Send-Q`는 해당 소켓의 최대 backlog = min(listen(N), somaxconn). `Recv-Q`가 이 값에 도달하면 오버플로
- `TcpExtListenOverflows` / `TcpExtListenDrops`는 거의 항상 같은 값. ListenDrops는 SYN cookie 없이 drop된 SYN, ListenOverflows는 accept queue 가득 찬 상황. 두 카운터를 함께 보는 것이 정확함
- `tcp_tw_reuse=1`은 TIME_WAIT 소켓이 있을 때만 효과. TIME_WAIT 만료 후에는 아무 효과 없음
- `EADDRNOTAVAIL`은 에페머럴 포트 고갈의 정확한 오류코드. 이 오류를 보면 ip_local_port_range 먼저 확인
- somaxconn 오버플로 시 클라이언트에 RST가 아닌 조용한 드롭이 발생 → timeout만 경험. 오버플로 원인 진단이 어려운 이유

**트러블슈팅**

| 증상 | 원인 | 해결 |
|------|------|------|
| 타이밍 문제로 ss 출력에 서버 소켓 없음 | 서버가 ss 실행 전에 종료됨 | sleep 시간을 서버 수명보다 짧게 조정 |
| tcp_tw_reuse=1 후에도 포트 고갈 | TIME_WAIT 소켓이 이미 만료되어 재사용할 대상 없음 | TIME_WAIT 소켓이 있는 상태에서 즉시 재시도해야 효과 확인 가능 |

---

## 학습 키워드 누적 정리

- `ss -lnt` — Recv-Q(대기 연결), Send-Q(max backlog), 오버플로 여부 실시간 확인
- `nstat -az | grep ListenOverflow` — accept queue 오버플로 누적 카운터
- `nstat -az | grep ListenDrop` — SYN 드롭 카운터
- `ss -ant | grep TIME-WAIT | wc -l` — TIME_WAIT 소켓 수
- `EADDRNOTAVAIL` — 에페머럴 포트 고갈 오류 코드
- `net.core.somaxconn` — accept queue 상한. K8s 노드 최소 65535 권장
- `net.ipv4.tcp_max_syn_backlog` — SYN_RECV queue. DDoS 방어와 연관
- `net.ipv4.tcp_tw_reuse` — 1: TIME_WAIT 포트 재사용 (동일 dst IP:port 필수)
- `net.ipv4.tcp_fin_timeout` — TIME_WAIT 유지 시간. 줄이면 포트 회전 빠름
- `net.ipv4.ip_local_port_range` — 에페머럴 포트 범위. 고부하 환경에서 1024-65535 권장

## 막혔던 점 / 다음에 더 파볼 것

- `tcp_tw_reuse=1` 효과를 라이브로 보려면 TIME_WAIT가 존재하는 상태에서 즉시 같은 목적지에 연결해야 함. 타이밍 조절 실험 여지 있음
- `tcp_syncookies`와 `somaxconn` 간 상호작용: syncookies 활성화 시 SYN queue가 넘쳐도 쿠키로 3WHS 완료 가능 → accept queue 오버플로와 구분해서 이해 필요
- `SO_REUSEPORT`: 여러 소켓이 같은 포트를 공유해 accept 병렬 처리. Nginx worker 당 소켓 방식. somaxconn과 별개의 최적화
- 실제 K8s에서 `kube-apiserver` 또는 Istio sidecar의 somaxconn 설정이 노드 sysctl보다 낮게 걸릴 수 있는 문제 탐색 여지 있음
