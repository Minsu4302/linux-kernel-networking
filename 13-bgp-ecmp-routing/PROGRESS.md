# PROGRESS: BGP 라우팅 & ECMP

## 진행 로그

### 2026-06-27

**한 일**
- FRRouting 설치 및 BGP 3-노드 환경 구성 (AS 65001/65002/65003)
- GCP /32 unnumbered 환경에서 eBGP 피어링 문제 해결
- ECMP: vm-01이 10.200.1.0/24 경로를 vm-02(AS65002), vm-03(AS65003) 두 곳에서 학습
- BGP 수렴 시간 측정: Graceful Shutdown 6ms

**실험 결과**

| 측정 항목 | 결과 |
|-----------|------|
| BGP 세션 수 | 2 (vm-01↔vm-02, vm-01↔vm-03) |
| ECMP 경로 수 | 2 (`*>` best + `*=` multipath) |
| Graceful Shutdown 수렴 시간 | **6 ms** |
| Hold Timer 설정 | 3s keepalive / 9s hold |
| 이론적 Hard Failure 수렴 | ~9초 (Hold Timer 만료) |

**BGP 테이블 (vm-01 수신)**

```
Network          Next Hop         AS Path
*>  10.200.1.0/24    10.178.0.3   65002 i    ← best
*=                   10.178.0.4   65003 i    ← ECMP (multipath)
```

**배운 것 (TIL)**
- **GCP /32 unnumbered 환경**: GCP VM의 IP는 서브넷 마스크 없이 /32로 할당. FRR은 피어를 "directly connected"로 인식 못 해 `No path to specified Neighbor` 에러 발생
- **ebgp-multihop**: eBGP 피어가 직접 연결이 아닐 때 필요. GCP에서는 모든 VM 트래픽이 게이트웨이(10.178.0.1)를 통해 라우팅되므로 `ebgp-multihop 2` 필요
- **disable-connected-check**: FRR의 eBGP 직접 연결 검증을 우회. GCP처럼 /32 인터페이스 환경에서 필수
- **no bgp ebgp-requires-policy**: FRR 8.x 기본 정책 — 명시적 route-map 없이는 eBGP 경로를 받지 않음. 개발/학습 환경에서는 이 옵션으로 비활성화
- **BGP `(Policy)` 상태**: FRR 8.x에서 route-map 없이 경로를 받으면 `State/PfxRcd` 가 숫자 대신 `(Policy)` 로 표시됨
- **Graceful Shutdown vs Hard Failure**:
  - `systemctl stop frr`: BGP CEASE NOTIFICATION 전송 → 피어가 즉시 경로 철회 (6ms)
  - 네트워크 단절 / `kill -9`: Hold Timer 만료까지 대기 (설정: 9초)
- **BGP `clear bgp soft`**: 세션 끊지 않고 경로 재광고 트리거. 설정 변경 후 반드시 실행

**트러블슈팅**

| 증상 | 원인 | 해결 |
|------|------|------|
| BGP `Active` 상태 + `No path to specified Neighbor` | GCP VM IP가 /32 unnumbered → FRR이 피어를 "직접 연결"로 인식 못 함 | `ebgp-multihop 2` + `disable-connected-check` + FRR 내 static route 추가 |
| BGP `(Policy)` 상태, PfxRcd=0 | FRR 8.x 기본 정책: 명시적 route-map 없으면 eBGP 경로 차단 | `no bgp ebgp-requires-policy` |
| PfxRcd=0 (policy 해제 후에도) | BGP 세션이 route 존재 전에 연결됨 → 재광고 필요 | `clear bgp ipv4 unicast * soft` |
| ping 10.200.1.1 실패 | GCP VPC에 10.200.1.0/24 경로 없음 (VM 루프백에만 존재) | GCP 네트워킹 한계 — BGP 학습 자체는 정상 |

---

## 학습 키워드 누적 정리

- `FRRouting (FRR)` — BGP, OSPF 등을 구현한 오픈소스 라우팅 데몬
- `vtysh` — FRR 통합 CLI (Cisco IOS 유사 인터페이스)
- `bgpd` — FRR의 BGP 데몬 프로세스
- `zebra` — FRR의 커널 라우팅 동기화 컴포넌트
- `eBGP (external BGP)` — 서로 다른 AS 간 BGP 피어링
- `ebgp-multihop` — 직접 연결되지 않은 eBGP 피어 허용
- `disable-connected-check` — eBGP 직접 연결 검증 우회
- `no bgp ebgp-requires-policy` — FRR 8.x 기본 policy 요구 비활성화
- `bgp bestpath as-path multipath-relax` — AS-PATH 길이가 같으면 ECMP 허용
- `maximum-paths 4` — ECMP 최대 경로 수
- `*>` (BGP best path) / `*=` (BGP multipath) — FRR BGP 테이블 상태 코드
- `clear bgp ipv4 unicast * soft` — 세션 유지하며 경로 재광고
- `BGP Hold Timer` — 피어가 응답 없을 때 세션 끊는 타이머 (이 실습: 9초)
- `BGP CEASE NOTIFICATION` — Graceful Shutdown 시 전송하는 BGP 메시지
- `/32 unnumbered` — GCP VM 인터페이스 할당 방식, 서브넷 없이 호스트 단위 IP

## 막혔던 점 / 다음에 더 파볼 것

- `kill -9 bgpd` 로 Hard Failure 재현 후 실제 Hold Timer(9초) 수렴 측정
- BFD(Bidirectional Forwarding Detection) 연동 시 수렴 시간 50ms 이하로 단축 가능
- GCP VPC에 커스텀 라우트 추가해 10.200.1.0/24 ping 연결 테스트
