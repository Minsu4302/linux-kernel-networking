# PROGRESS: Network Policy 확장성 벤치마크

## 진행 로그

### 2026-06-26

**한 일**
- iptables dummy 규칙 N개 생성 스크립트 작성 (`01-setup-iptables-rules.sh`)
- ping 200회 RTT 측정 스크립트 작성 (`02-measure-latency.sh`)
- ipset 방식 동일 IP 집합 적용 스크립트 작성 (`03-setup-ipset-rules.sh`)
- 5단계 벤치마크 실행: Baseline / iptables-100 / iptables-1000 / iptables-5000 / ipset-5000

**벤치마크 결과 (lab-vm-01 → lab-vm-02, ping 200회 avg RTT)**

| 조건 | avg RTT (ms) | 규칙 수 | 증가 |
|------|-------------|---------|------|
| Baseline | 0.294 ms | 0 | — |
| iptables-100 | 0.291 ms | 100 | ≈0 |
| iptables-1000 | 0.303 ms | 1,000 | +0.009 ms |
| iptables-5000 | 0.386 ms | 5,000 | +0.092 ms (+31%) |
| ipset-5000 | 0.294 ms | 5,000 (ipset) | +0.000 ms |

핵심 수치:
- iptables 5000 규칙: baseline 대비 **+31% 지연 증가** (O(N) 선형 탐색)
- ipset 5000 IP: baseline과 **완전히 동일** (O(1) 해시 조회)
- 두 방식 모두 동일한 5000개 IP를 다루지만 내부 구현의 복잡도 차이가 RTT로 직결됨

**배운 것 (TIL)**
- **iptables O(N) 실증**: 규칙이 100→1000→5000으로 10배씩 늘어날 때 지연이 단계적으로 증가. K8s 클러스터에서 파드 수천 개가 생기면 수만 개 규칙 → 성능 문제의 근원
- **ipset O(1) 실증**: 5000개 IP를 해시셋으로 관리하면 iptables 규칙은 단 2개. 조회는 해시 1회로 끝나 RTT가 baseline과 동일
- **ipset 구조**: `hash:ip` 타입이 기본. 네트워크 대역은 `hash:net`, IP:포트 조합은 `hash:ip,port`로 확장 가능
- **iptables + ipset 연동**: `-m set --match-set <set_name> src` 옵션으로 ipset을 iptables 규칙에 연결. 규칙은 1개, IP 멤버 관리는 ipset으로 분리
- **Cilium eBPF의 위치**: ipset과 동일한 O(1)이지만 netfilter를 완전히 우회(XDP/TC hook)하고 L7 정책까지 커널에서 처리. iptables → ipset → Cilium 순서가 성능 개선의 자연스러운 진화

**트러블슈팅**

| 증상 | 원인 | 해결 |
|------|------|------|
| `sudo: ipset: command not found` | ipset이 GCP Ubuntu 기본 이미지에 미설치 | `sudo apt-get install -y ipset` |

---

## 학습 키워드 누적 정리

- `iptables -L INPUT --line-numbers` — 규칙 목록 번호 포함 출력
- `ipset create <name> hash:ip` — IP 해시셋 생성
- `ipset add <name> <ip>` — 멤버 추가
- `-m set --match-set <name> src` — iptables에서 ipset 참조
- `ipset list <name>` — 셋 내용 확인
- `ipset destroy <name>` — 셋 삭제
- `O(N) vs O(1)` — iptables 규칙 수 vs ipset 해시 조회 복잡도
- `hash:ip / hash:net / hash:ip,port` — ipset 타입별 용도

## 막혔던 점 / 다음에 더 파볼 것

- iptables-save / iptables-restore 를 이용한 대량 규칙 일괄 적용 시 성능 차이 (개별 `-A` vs restore 배치)
- ipset과 nftables 비교 (nftables는 자체적으로 집합 자료구조 내장)
- Cilium Network Policy 실제 적용 시 BPF 맵 구조 확인 (`bpftool map show`)
