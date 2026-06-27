# 13. BGP 라우팅 & ECMP

## 왜 이 주제인가

클라우드 데이터센터의 Spine-Leaf 아키텍처는 BGP로 동작한다. AWS/GCP의 VPC 라우팅, Kubernetes의 Calico CNI, MetalLB의 LoadBalancer IP 광고가 모두 BGP 기반이다. 이 주제에서는 FRRouting으로 3-노드 BGP 환경을 구성하고, 동일 목적지로 가는 두 경로(ECMP)가 실제로 트래픽을 분산하는 것을 확인한다. 이후 하나의 BGP 피어를 끊어 경로 수렴(Convergence)이 몇 초 만에 완료되는지 밀리초 단위로 측정한다.

---

## 아키텍처

```
                    AS 65001
                   [lab-vm-01]
                   10.178.0.2
                  (클라이언트/측정)
                  /              \
     eBGP 피어링                   eBGP 피어링
            /                          \
     AS 65002                       AS 65003
    [lab-vm-02]                    [lab-vm-03]
    10.178.0.3                     10.178.0.4
         |                              |
   lo: 10.200.1.1/32             lo: 10.200.1.1/32
   (목적지 광고)                  (동일 목적지 광고)
```

vm-01은 10.200.1.1/32로 가는 경로를 두 곳에서 받아 ECMP로 분산.  
vm-02 BGP 세션이 끊기면 vm-03 경로만 남음 → 수렴 시간 측정.

### BGP 세션 구성

| 피어 관계 | 타입 | AS |
|-----------|------|-----|
| vm-01 ↔ vm-02 | eBGP | 65001 ↔ 65002 |
| vm-01 ↔ vm-03 | eBGP | 65001 ↔ 65003 |

---

## 실습 환경

| VM | 물리 IP | AS | 역할 |
|----|---------|-----|------|
| lab-vm-01 | 10.178.0.2 | 65001 | 클라이언트, ECMP 수신자, 수렴 시간 측정 |
| lab-vm-02 | 10.178.0.3 | 65002 | BGP 피어, 10.200.1.1/32 광고 |
| lab-vm-03 | 10.178.0.4 | 65003 | BGP 피어, 10.200.1.1/32 광고 |

> 실제 IP는 VM 시작 후 `ip addr show ens4` 로 확인. 위 IP는 예시.

---

## 실험 방법

1. **FRRouting 설치**: 3대 모두
2. **BGP 설정**: vm-01이 vm-02, vm-03과 eBGP 피어링
3. **경로 광고**: vm-02, vm-03이 각자 loopback(10.200.1.1/32) 광고
4. **ECMP 확인**: `ip route show 10.200.1.1/32` → 두 next-hop
5. **수렴 시간 측정**: vm-02 FRR 중지 → vm-01에서 경로 교체 시간 기록

---

## 스크립트 목록

| 파일 | 설명 | 실행 노드 |
|------|------|---------|
| `scripts/01-install-frr.sh` | FRRouting 설치 | 전체 |
| `scripts/02-setup-vm01.sh` | BGP 설정 (vm-01, AS 65001) | vm-01 |
| `scripts/03-setup-vm02.sh` | BGP 설정 + 경로 광고 (vm-02, AS 65002) | vm-02 |
| `scripts/04-setup-vm03.sh` | BGP 설정 + 경로 광고 (vm-03, AS 65003) | vm-03 |
| `scripts/05-verify-bgp.sh` | BGP 세션 및 라우팅 테이블 확인 | vm-01 |
| `scripts/06-convergence-test.sh` | vm-02 다운 후 수렴 시간 측정 | vm-01 |
| `scripts/07-cleanup.sh` | FRR 설정 초기화 | 전체 |

---

## 핵심 개념

### BGP (Border Gateway Protocol)

```
AS (Autonomous System): 동일한 라우팅 정책을 가진 네트워크 집합
  eBGP: 서로 다른 AS 간 피어링
  iBGP: 같은 AS 내 피어링

BGP 경로 선택 기준 (순서대로):
  1. Weight (Cisco 전용)
  2. LOCAL_PREF (높을수록 선호)
  3. AS-PATH 길이 (짧을수록 선호)
  4. MED 값
  5. eBGP > iBGP
  6. IGP metric (next-hop까지 거리)
```

### ECMP (Equal Cost Multi-Path)

```
목적지: 10.200.1.1/32
  next-hop 1: 10.178.0.3 (via vm-02)  ─┐
  next-hop 2: 10.178.0.4 (via vm-03)  ─┴─ 패킷 해시로 분산
```

Linux 커널은 5-tuple(src IP, dst IP, proto, src port, dst port)을 해시해 next-hop을 선택한다.

### BGP 수렴 (Convergence)

```
vm-02 FRR 종료
  → BGP Hold Timer 만료 (기본 90초, 설정으로 단축 가능)
  → vm-01이 vm-02 경로 철회
  → 라우팅 테이블에서 vm-02 next-hop 제거
  → vm-03 경로만 남음

Hold Timer를 3초로 설정하면 수렴 시간 ~3초
```

### FRRouting 구조

```
FRRouting (FRR)
  ├── bgpd   — BGP 데몬
  ├── zebra  — 커널 라우팅 테이블과 동기화
  ├── ospfd  — OSPF 데몬 (미사용)
  └── vtysh  — 통합 CLI (Cisco IOS 유사)
```

---

## 참고

- [FRRouting 공식 문서](https://docs.frrouting.org/)
- [BGP Best Path Selection](https://docs.frrouting.org/en/latest/bgp.html)
- [Linux ECMP](https://www.kernel.org/doc/html/latest/networking/ip-sysctl.html)
