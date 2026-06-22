# PROGRESS: K8s Service 가상 구현

## 진행 로그

### 2026-06-22

**한 일**
- GCP VM(lab-vm-01, e2-standard-2, asia-northeast3-a) 생성 및 접속 환경 구성
- ip netns + Linux bridge(br0) + veth pair로 pod-a/b/c 네트워크 namespace 구성
- iptables DNAT + statistic 모듈로 ClusterIP(10.96.0.1:80) 부하분산 구현
- NodePort(127.0.0.1:30080) → Pod DNAT 구현 (트러블슈팅 포함)
- IPVS NAT 모드로 동일 시나리오 재구현 (완전한 round-robin 확인)
- iptables vs IPVS 규칙 관리 속도 벤치마크 (1/100/1000/5000 서비스)

**배운 것 (TIL)**
- `iptables -m statistic --mode random --probability`는 누적 확률로 계산해야 함: 3분의 1 분산이면 Rule1=0.333, Rule2=0.5(나머지의 절반), Rule3=catch-all
- IPVS round-robin은 결정론적(c→b→a→c→b→a 패턴)이지만, iptables statistic은 확률적이라 9번 테스트에서도 분포 편차 발생
- iptables-restore는 단일 배치 syscall로 전체 규칙을 원자적으로 적용. 5000서비스=728ms
- `route_localnet=1` 없으면 src=127.0.0.1 패킷이 non-loopback 인터페이스로 라우팅될 때 커널이 martian source로 드롭
- IPVS의 진짜 장점은 데이터 플레인의 O(1) 해시 룩업 — 이 벤치마크는 컨트롤 플레인만 측정
- GCP VM 인터페이스는 eth0가 아니라 ens4, IP는 `/32` prefix mask 사용

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| OS Login SSH 실패: "Permission denied (publickey)" | VM 생성 시 `enable-oslogin=true` 설정했으나 IAM 역할(`roles/compute.osLogin`) 미부여 | `gcloud compute instances add-metadata lab-vm-01 --metadata=enable-oslogin=false` 후 재접속 |
| `which ipvsadm` 실패로 체인 끊어짐 | ipvsadm 미설치 | `sudo apt-get install -y ipvsadm` |
| `ipvsadm --version` → "Permission denied (you must be root)" | ipvsadm은 IPVS 커널 서브시스템 접근에 root 필요 | `sudo ipvsadm --version` |
| NodePort `curl http://localhost:30080/` hang | (1) src=127.0.0.1 패킷이 OUTPUT DNAT → 재라우팅 시 br0으로 나가려 할 때 커널이 martian source로 드롭. (2) tcpdump br0 0 packets 확인으로 원인 특정 | `sudo sysctl -w net.ipv4.conf.all.route_localnet=1` + `net.ipv4.conf.br0.route_localnet=1` |
| NodePort curl 즉시 실패: "connect to ::1 port 30080 failed: Connection refused" | curl의 Happy Eyeballs 알고리즘이 IPv6(::1)으로 fallback. IPv4 hang + IPv6 즉시 실패 → 전체 실패 | `curl -4` 또는 IP 직접 입력 `curl http://127.0.0.1:30080/` |
| HOST_IP 감지 실패: `ip -4 addr show eth0 → Device "eth0" does not exist` | GCP VM의 기본 네트워크 인터페이스는 `ens4` | `ip route get 8.8.8.8 \| grep -oP 'src \K[\d.]+'` 로 동적 감지 |
| `lsmod \| grep nf_nat` 아무것도 출력 안 됨 | 커널 6.8에서 nf_nat이 loadable module이 아닌 built-in으로 컴파일됨 | 문제 없음 — iptables DNAT 동작 확인으로 검증 |

---

## 학습 키워드 누적 정리

**커널 네트워킹 기초**
- `ip netns add/exec/del` — network namespace 생성/실행/삭제
- `ip link add TYPE veth peer name` — veth pair(양방향 가상 이더넷) 생성
- `ip link set DEVICE netns NS` — 인터페이스를 namespace로 이동
- `ip link add TYPE bridge` + `ip link set master` — Linux bridge 구성
- `net.ipv4.ip_forward=1` — 호스트 IP 포워딩 활성화
- `net.ipv4.conf.all.route_localnet=1` — 127.0.0.0/8 martian source 허용

**iptables NAT**
- `-t nat -A OUTPUT/PREROUTING -j DNAT --to-destination IP:PORT` — 목적지 변환
- `-t nat -A POSTROUTING -j MASQUERADE` — source IP를 출구 인터페이스 IP로 변환
- `-m statistic --mode random --probability X` — 확률 기반 규칙 매칭
- `iptables-restore --noflush` — 기존 규칙 유지하며 추가 로드

**IPVS**
- `ipvsadm -A -t VIP:PORT -s rr` — 가상 서버 생성 (round-robin 스케줄러)
- `ipvsadm -a -t VIP:PORT -r REAL:PORT -m` — real server 추가 (NAT/Masq 모드)
- `ipvsadm -Ln` — 현재 가상 서버 목록 확인
- `ipvsadm -R` — stdin에서 설정 복원 (배치 입력)
- `ipvsadm -C` — 전체 초기화
- 커널 모듈: `ip_vs`, `ip_vs_rr`, `ip_vs_wrr`, `ip_vs_sh`, `nf_conntrack`

**성능 개념**
- control plane vs data plane — 규칙 관리와 패킷 포워딩은 별개로 측정해야 함
- O(N) 순차 탐색 (iptables) vs O(1) 해시 룩업 (IPVS) — 데이터 플레인의 핵심 차이
- martian source — RFC 1812에서 정의한 "라우팅 불가능한 주소에서 온 패킷" (커널이 드롭)
- Happy Eyeballs (RFC 8305) — curl이 IPv4/IPv6를 동시 시도하는 알고리즘

---

## 막혔던 점 / 다음에 더 파볼 것

- **데이터 플레인 벤치마크 미완**: 이 실습은 control-plane(규칙 관리) 속도만 측정했다. 실제 O(N) vs O(1) 패킷 포워딩 지연 차이를 보려면 hping3나 wrk로 패킷 수천 개를 쏘면서 `iptables -t nat -L --line-numbers -v`의 pkts 카운터 증가 속도를 비교해야 함.
- **kube-proxy IPVS 모드 실제 구현**: 실제 kube-proxy는 `ipvsadm -R` 대신 Go의 netlink 라이브러리로 직접 커널과 통신 → 훨씬 빠른 규칙 업데이트. 02번 주제(L4/L7 로드밸런서 비교)에서 더 파볼 예정.
- **nftables 비교**: 최신 배포판은 iptables → nftables로 전환 중. K8s 1.29+에서 nftables kube-proxy 지원 추가됨. 성능 비교가 궁금함.
