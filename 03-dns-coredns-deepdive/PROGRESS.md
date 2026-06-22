# PROGRESS: DNS 동작 원리 & CoreDNS 심층 분석

## 진행 로그

### 2026-06-22

**한 일**
- systemd-resolved DNS 불통 원인 분석 및 resolv.conf 교체로 해결
- tcpdump + dig로 재귀 DNS 조회 패킷 흐름 관찰
- K8s ndots:5 + search domain이 만드는 불필요한 DNS 쿼리를 host + tcpdump로 계수
- CoreDNS 1.11.3 바이너리 설치 및 로컬 리졸버 실행
- CoreDNS cache MISS vs HIT 레이턴시 실측 (44ms → 0.24ms, 180배 단축)

**배운 것 (TIL)**
- `dig`는 `/etc/resolv.conf`의 `ndots`와 `search` 설정을 기본적으로 무시한다. ndots 효과를 보려면 glibc resolver를 사용하는 `host`, `getent hosts`, 또는 `dig +search`를 써야 한다.
- `host google.com` (dot 1개, ndots:5 기준 미달) → search domain 3개를 NXDomain으로 낭비한 뒤 마지막에 원래 이름 조회. 총 4회 쿼리, 134ms. FQDN `google.com.`은 1회 35ms.
- CoreDNS 캐시 HIT 응답의 DNS 플래그에 `aa`(Authoritative Answer) 비트가 켜진다. CoreDNS가 "내가 직접 아는 답"이라고 선언하는 것.
- GCP VM에서 `systemd-resolved`가 외부 도메인 리졸브를 못 하는 경우가 있다. `/etc/resolv.conf`가 systemd-resolved의 stub(127.0.0.53)을 가리키는 symlink인데, stub 자체가 업스트림 설정 없이 뜨는 경우. 정적 파일로 교체하는 것이 가장 빠른 해결책.
- `echo "127.0.0.1 $(hostname)" >> /etc/hosts`를 통해 sudo의 hostname 조회 실패를 방지할 수 있다. sudo는 내부적으로 자신이 실행된 호스트명을 리졸브하려 하는데, 실패하면 매번 경고를 출력하고 타임아웃만큼 지연된다.

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `curl github.com` → "Could not resolve host" | GCP VM의 systemd-resolved(127.0.0.53)가 외부 도메인 리졸브 실패. `/etc/systemd/resolved.conf.d/dns.conf`에 8.8.8.8 추가 후 재시작해도 stub 자체가 응답 안 함 | `/etc/resolv.conf` symlink를 삭제하고 `nameserver 8.8.8.8` 정적 파일로 대체 |
| `dig google.com`에서 ndots:5 search domain 효과 없음 | `dig`은 자체 resolver를 사용하며 resolv.conf의 ndots/search를 기본 무시 | `host google.com` 사용 (glibc resolver 경유, ndots 적용됨) |
| `sudo: unable to resolve host lab-vm-01` 경고 반복 + 명령 지연 | `/etc/hosts`에 자신의 hostname 미등록. sudo가 hostname 리졸브를 시도하다 타임아웃 | `echo "127.0.0.1 $(hostname)" \| sudo tee -a /etc/hosts` |
| CoreDNS 다운로드 실패: "Could not resolve host: github.com" | 위 DNS 불통 문제가 아직 해결 전 상태에서 시도 | DNS 먼저 복구 후 재시도 |

---

## 학습 키워드 누적 정리

**DNS 계층 구조**
- Root NS — 13개 논리 서버(`a.root-servers.net` ~ `m.root-servers.net`), TLD NS 주소 반환
- TLD NS — `.com`, `.kr` 등 담당, 도메인의 Authoritative NS 반환
- Authoritative NS — 해당 도메인의 실제 레코드 보유 (A, AAAA, MX 등)
- Recursive Resolver — 클라이언트 대신 Root→TLD→Auth 순서로 반복 조회 후 최종 답 반환 (8.8.8.8, 1.1.1.1)

**DNS 레코드 타입**
- `A` — IPv4 주소
- `AAAA` — IPv6 주소
- `MX` — 메일 서버
- `CNAME` — 별칭(alias)
- `NS` — Name Server 지정
- `SOA` — Start of Authority, zone 메타데이터

**resolv.conf 설정**
- `nameserver` — 쿼리를 보낼 DNS 서버 IP (최대 3개)
- `search` — 짧은 hostname에 붙여볼 도메인 suffix 목록
- `options ndots:N` — hostname의 점 개수가 N 미만이면 search domain을 먼저 시도
- FQDN — 끝에 `.`을 붙이면 절대 이름으로 인식, search domain 무시

**dig 주요 옵션**
- `+noall +answer` — 응답 레코드만 출력
- `+short` — IP만 출력
- `+stats` — 쿼리 시간 포함 통계
- `+time=N` — 타임아웃 N초
- `@SERVER -p PORT` — 특정 서버/포트로 쿼리
- `+search` — resolv.conf의 search/ndots를 dig에도 적용

**CoreDNS**
- `Corefile` — 플러그인 체인 선언 파일. 존(zone) 블록 단위로 구성
- `forward . 8.8.8.8` — 모든 쿼리를 8.8.8.8로 위임
- `cache 60` — 60초 TTL로 응답 캐시
- `log` — 각 쿼리의 rcode, latency 로깅
- `aa` 플래그 — 캐시 히트 응답에서 AuthoritativeAnswer 비트 설정

**시스템 명령**
- `tcpdump -i any -n port 53 -l` — DNS 패킷 실시간 캡처 (`-l` 라인 버퍼링)
- `host DOMAIN` — glibc resolver 경유 조회 (ndots 적용)
- `dig @SERVER -p PORT` — 특정 리졸버 직접 쿼리
- `resolvectl status` — systemd-resolved 업스트림 DNS 및 상태 확인

---

## 막혔던 점 / 다음에 더 파볼 것

- **CoreDNS autopath 플러그인**: search domain 쿼리를 클라이언트 대신 CoreDNS가 처리해 클라이언트 쿼리를 1회로 줄이는 메커니즘. 실제 K8s에서 ndots:5 오버헤드를 줄이는 공식 방법.
- **DNS over TCP**: 응답이 512바이트 초과 시 TCP로 재쿼리. `+tcp` 플래그로 강제 가능. DNSSEC, 대형 zone transfer 시 필수.
- **DNSSEC**: 응답 위변조를 막는 서명 체계. `dig +dnssec`로 DS/RRSIG 레코드 확인 가능.
- **NXDomain 캐싱 (Negative Cache)**: CoreDNS cache는 NOERROR뿐 아니라 NXDomain도 캐싱. ndots:5 환경에서 첫 번째 NXDomain 응답 이후에는 캐시에서 빠르게 응답 가능. TTL은 SOA의 minimum 값 기준.
