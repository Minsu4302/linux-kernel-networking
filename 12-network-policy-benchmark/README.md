# 12. Network Policy 확장성 벤치마크

## 왜 이 주제인가

Kubernetes Network Policy는 내부적으로 iptables 규칙으로 변환된다. 파드가 1000개, 규칙이 5000개인 클러스터에서 iptables는 패킷마다 규칙을 순서대로 스캔(O(N))하기 때문에, 규칙이 늘어날수록 지연이 선형으로 증가한다. 이 주제에서는 iptables → ipset 순서로 동일한 조건을 실험하며 O(N) vs O(1) 차이를 수치로 확인하고, 실무에서 대규모 클러스터가 왜 Cilium eBPF 기반으로 이동하는지 구조적으로 이해한다.

---

## 아키텍처

```
[lab-vm-01] 클라이언트 (ping / iperf3 sender)
10.178.0.2

          ──────────────────────────────────→

[lab-vm-02] 서버 (Network Policy 적용 노드)
10.178.0.3
  │
  ▼
iptables INPUT chain
  ├── Rule 1: -s 192.168.1.1 -j ACCEPT   ←── dummy ACCEPT rule #1
  ├── Rule 2: -s 192.168.1.2 -j ACCEPT   ←── dummy ACCEPT rule #2
  ├── ...
  ├── Rule N: -s 192.168.1.N -j ACCEPT   ←── 규칙 N개 순서대로 탐색
  └── Rule N+1: -s 10.178.0.2 -j ACCEPT  ←── 실제 허용 규칙 (맨 끝)
```

### iptables vs ipset 처리 구조

```
패킷 도착
  │
  ▼
[iptables INPUT chain]
  │
  ├── (iptables 방식) N개 규칙을 순서대로 비교 → O(N)
  │     규칙 1: src == 192.168.1.1?  No
  │     규칙 2: src == 192.168.1.2?  No
  │     ...
  │     규칙 N: src == 192.168.1.N?  No
  │     규칙 N+1: src == 10.178.0.2? Yes → ACCEPT
  │
  └── (ipset 방식) 단 1개 규칙으로 해시맵 조회 → O(1)
        규칙 1: src ∈ dummy_set?  No (해시 조회 1회)
        규칙 2: src ∈ allow_set?  Yes → ACCEPT
```

---

## 실습 환경

| VM | 물리 IP | 역할 |
|----|---------|------|
| lab-vm-01 | 10.178.0.2 | 클라이언트 (ping latency 측정) |
| lab-vm-02 | 10.178.0.3 | 서버 (iptables / ipset 규칙 적용) |

---

## 실험 방법

**규칙 수를 단계적으로 늘리며 ping RTT 측정**

| 단계 | 규칙 수 | 방식 |
|------|--------|------|
| Baseline | 0 | 규칙 없음 |
| iptables-100 | 100 | iptables ACCEPT dummy 규칙 |
| iptables-1000 | 1,000 | iptables ACCEPT dummy 규칙 |
| iptables-5000 | 5,000 | iptables ACCEPT dummy 규칙 |
| ipset-5000 | 5,000 IP → 1 rule | ipset + iptables `-m set --match-set` |

측정 지표:
- **ping avg RTT** (ms): 클라이언트가 느끼는 지연
- **`%sys` + `%softirq`**: 서버 측 CPU, netfilter 처리 비용

---

## 스크립트 목록

| 파일 | 설명 | 실행 노드 |
|------|------|---------|
| `scripts/01-setup-iptables-rules.sh` | N개 dummy iptables 규칙 생성 | vm-02 |
| `scripts/02-measure-latency.sh` | vm-01에서 ping RTT 측정 | vm-01 |
| `scripts/03-setup-ipset-rules.sh` | ipset 방식으로 동일 IP 집합 적용 | vm-02 |
| `scripts/04-compare.sh` | 결과 비교 출력 | vm-02 |
| `scripts/05-cleanup.sh` | iptables 규칙 및 ipset 전체 정리 | vm-02 |

---

## 핵심 개념

### iptables 선형 탐색 O(N)

```
네트워크 패킷 → iptables INPUT chain
  규칙 1 비교 → miss
  규칙 2 비교 → miss
  ...
  규칙 N 비교 → hit → ACCEPT/DROP

N이 5000이면 패킷마다 최대 5000번 비교
```

### ipset 해시 조회 O(1)

```
네트워크 패킷 → iptables INPUT chain
  규칙 1: -m set --match-set dummy_ips src → hash lookup (1회)
  → hit/miss 즉시 결정

N이 100만이어도 조회 시간 동일
```

### Cilium eBPF (구조 설명)

Cilium은 iptables 규칙 대신 **BPF 맵**을 사용한다. BPF 맵은 ipset과 유사하게 O(1) 해시맵이지만, 커널 XDP 레벨에서 동작해 netfilter 훅 자체를 우회한다. 또한 L7(HTTP path, gRPC method) 정책을 커널에서 직접 처리할 수 있어 iptables로는 불가능한 세분화된 정책을 구현한다.

| | iptables | ipset | Cilium eBPF |
|-|----------|-------|-------------|
| 조회 복잡도 | O(N) | O(1) | O(1) |
| 처리 위치 | netfilter | netfilter | XDP / TC hook |
| L7 정책 | 불가 | 불가 | 가능 |
| 대규모 클러스터 | 규칙 업데이트 느림 | 빠름 | 빠름 + 무중단 |

---

## 참고

- [iptables vs ipset: performance](https://ipset.netfilter.org/why.html)
- [Kubernetes Network Policy internals](https://www.tigera.io/blog/network-policies-iptables/)
- [Cilium eBPF dataplane](https://docs.cilium.io/en/stable/network/ebpf/)
