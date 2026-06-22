# PROGRESS: L4/L7 로드밸런서 비교

## 진행 로그

### 2026-06-22

**한 일**
- lab-vm-01(e2-standard-2, topic 01에서 생성한 VM 재사용)에 haproxy, nginx, wrk 설치
- python3 내장 HTTP 서버로 백엔드 3대(127.0.0.1:8081/8082/8083) 구성
- IPVS NAT 모드 벤치마크: VIP(10.96.0.100:80) → 백엔드 3대
- HAProxy L4(mode tcp) 벤치마크
- HAProxy L7(mode http) 벤치마크
- Nginx L7(upstream round-robin) 벤치마크
- 측정 오염 발생(이전 haproxy 프로세스 잔존) → 강제 종료 후 4종 전부 재측정

**배운 것 (TIL)**
- HAProxy `mode tcp`는 TCP 연결 단위로 분산한다. wrk가 100개 persistent connection을 유지하는 경우, 초반 라운드로빈 이후 연결이 고정돼 per-request 분산이 안 된다. L7 `mode http`보다 RPS가 낮게 나온 이유.
- HAProxy `mode http`는 백엔드에 keepalive 연결 풀을 유지하고, HTTP 요청마다 유휴 백엔드로 분산한다. 유저스페이스 프록시임에도 L4보다 효율이 높은 워크로드가 존재한다.
- IPVS는 커널 `LOCAL_IN` 훅에서 패킷 DNAT만 수행하므로 LB 자체의 TCP 스택이 없다. 이로 인해 유저스페이스 LB보다 p50이 2배 이상 낮았다(7ms vs 11~14ms).
- `sudo haproxy -f CFG -p PIDFILE`로 데몬을 시작할 때, PIDFILE 경로를 정확히 기록해 두지 않으면 종료 시 실패한다. 스크립트 내 변수로 통일 관리해야 한다.
- `nginx -s quit`는 실행 시 사용한 `-c CONFIG`와 동일한 설정을 줘야 올바른 pid 파일을 찾는다. 그렇지 않으면 기본 `/run/nginx.pid`를 참조해 실패.
- `sudo fuser -k 8080/tcp`는 해당 포트를 사용 중인 프로세스에 SIGKILL을 보내는 가장 빠른 포트 강제 해제 방법.

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| HAProxy L4/L7/Nginx wrk 결과가 모두 ~1,842 RPS로 동일 | 수동 테스트용 haproxy가 PID 파일 경로 불일치로 종료되지 않고 남아있어, 이후 측정이 모두 해당 프로세스로 향함 | `sudo fuser -k 8080/tcp` + `sudo pkill -9 haproxy`로 강제 정리 후 4종 전부 재측정 |
| `cat > /tmp/hp-l7.cfg` 실패: "Permission denied" | 이전에 `sudo bash`로 스크립트를 실행해 파일이 root 소유가 됨 | `sudo rm -f /tmp/hp-l7.cfg` 후 일반 사용자 권한으로 재작성 |
| `nginx -s quit` 실패: "open() /run/nginx.pid failed (2)" | nginx를 `-c /tmp/ng.conf`로 시작(pid는 /tmp/ng.pid에 저장)했지만, quit 명령 시 `-c` 미지정으로 기본 경로(/run/nginx.pid) 참조 | `sudo kill $(cat /tmp/lb-nginx.pid)` 또는 `sudo nginx -c /tmp/lb-nginx.cfg -s quit` 사용 |
| IPVS 측정 시 "connect failed" | `net.ipv4.conf.all.route_localnet=1` 미설정으로 로컬 백엔드(127.0.0.1)로의 DNAT 패킷이 martian source 드롭 | `sudo sysctl -w net.ipv4.conf.all.route_localnet=1` 적용 후 측정 |

---

## 학습 키워드 누적 정리

**로드밸런서 계층**
- L4(TCP 레이어): 패킷 헤더만 보고 DNAT. HTTP 파싱 없음. per-connection 분산.
- L7(HTTP 레이어): HTTP 헤더, URL, 쿠키 등 분석. per-request 분산 + keepalive 풀.

**IPVS 커맨드**
- `ipvsadm -A -t VIP:PORT -s rr` — 가상 서버 생성 (round-robin)
- `ipvsadm -a -t VIP:PORT -r REAL:PORT -m` — real server 추가 (-m: NAT/Masq 모드)
- `ipvsadm -C` — 전체 초기화
- `ipvsadm -Ln` — 현재 가상 서버 및 real server 목록

**HAProxy 설정 키워드**
- `mode tcp` / `mode http` — L4 vs L7 전환
- `balance roundrobin` — 기본 분산 알고리즘
- `timeout connect / client / server` — 연결 타임아웃 3종
- `haproxy -f CFG -p PIDFILE` — 데몬 모드 시작

**Nginx 설정 키워드**
- `upstream be { server ...; }` — 백엔드 풀 정의
- `proxy_pass http://be;` — 업스트림으로 요청 전달
- `access_log off;` — 로깅 비활성화 (벤치마크 시 I/O 오버헤드 제거)
- `nginx -c CONFIG -s quit` — 특정 설정 파일 기준으로 종료

**시스템 명령**
- `ss -tlnp | grep :PORT` — 포트 점유 확인
- `sudo fuser -k PORT/tcp` — 포트 강제 해제
- `sudo pkill -9 PROCNAME` — 프로세스 이름으로 강제 종료
- `ip addr add VIP/32 dev lo` — 루프백에 VIP 임시 추가

---

## 막혔던 점 / 다음에 더 파볼 것

- **데이터 플레인 심층 분석**: 이번 측정은 단순 RPS/레이턴시 비교. 실제로는 CPU 사용률(유저스페이스 LB vs 커널 IPVS), 연결 수 증가에 따른 스케일링 특성, TLS 오버헤드 포함 시 순위 변화 등을 추가로 측정하면 더 풍부한 데이터가 된다.
- **Envoy / Cilium**: 클라우드 네이티브 환경에서는 HAProxy/Nginx 대신 Envoy가 기본 사이드카. eBPF 기반 Cilium은 IPVS보다 더 낮은 계층에서 처리. 07번 주제(eBPF)에서 비교 예정.
- **HAProxy L4 keepalive 비교**: `option http-server-close` 또는 `option forwardfor`를 켜면 L4와 L7의 RPS 차이가 어떻게 변하는지 실험해보고 싶다.
