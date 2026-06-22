# 🐧 linux-kernel-networking

> Kubernetes나 클라우드 네트워킹을 "쓰는" 것에서 멈추지 않고, 그 아래에 깔린 Linux 커널 네트워크 기능을 직접 손으로 구현하며 동작 원리를 검증하는 스터디 레포지토리입니다.

K8s의 Service, CNI, VPN, DNS 같은 컴포넌트들은 사실 익숙한 Linux 기술(iptables, network namespace, VXLAN, eBPF, conntrack, sysctl 등)의 조합으로 만들어져 있습니다. 이 레포는 그 추상화를 한 단계씩 벗겨내고, GCP VM 위에서 동일한 동작을 직접 구현해보는 과정을 기록합니다.

---

## 🎯 진행 방식

- 주제 1개 = 브랜치 1개. `feature/0N-주제명` 브랜치에서 실습 → 커밋 → PR → 셀프 리뷰 → `main` 머지.
- 작업 규칙과 커밋/브랜치/리뷰 컨벤션은 [`CLAUDE.md`](./CLAUDE.md)에 정리되어 있습니다.
- 각 주제 폴더는 `README.md`(개념 정리)와 `PROGRESS.md`(트러블슈팅 로그, TIL) 두 문서로 구성됩니다.

## 🧭 진행 현황 및 순서

순서는 난이도와 의존성을 고려해 설계했습니다 (예: MTU 트러블슈팅은 터널링 직후, sysctl 튜닝은 eBPF로 커널 스택을 본 직후, VPN 비교는 Mesh에서 다룬 WireGuard 지식을 재사용).

| # | 주제 | 핵심 기술 | 인프라 | 상태 | 링크 |
|---|------|-----------|--------|------|------|
| 1 | K8s Service 가상 구현 | iptables(DNAT/SNAT), IPVS | VM 1대 | ✅ 완료 | [폴더](./01-k8s-service-from-scratch) |
| 2 | L4/L7 로드밸런서 비교 | IPVS vs HAProxy vs Nginx | VM 1대 | ⬜ 시작 전 | [폴더](./02-l4-l7-loadbalancer-comparison) |
| 3 | DNS 동작 원리 & CoreDNS | CoreDNS, dig, ndots | VM 1~2대 | ⬜ 시작 전 | [폴더](./03-dns-coredns-deepdive) |
| 4 | 터널링 & 오버레이 네트워크 | VXLAN, GRE, IP-in-IP | VM 2대 | ⬜ 시작 전 | [폴더](./04-tunneling-overlay-network) |
| 5 | MTU 트러블슈팅 & 파편화 | PMTUD, MSS Clamping | VM 2~3대 | ⬜ 시작 전 | [폴더](./05-mtu-fragmentation) |
| 6 | Conntrack & NAT 테이블 한계 | nf_conntrack | VM 1대 | ⬜ 시작 전 | [폴더](./06-conntrack-nat-table) |
| 7 | eBPF 기반 네트워크 분석 | eBPF, XDP, Cilium | VM 1대 | ⬜ 시작 전 | [폴더](./07-ebpf-cni-future) |
| 8 | TCP 커널 파라미터 튜닝 | sysctl, somaxconn, TIME_WAIT | VM 1대 | ⬜ 시작 전 | [폴더](./08-sysctl-tcp-tuning) |
| 9 | Ad-hoc & 메시 네트워크 | WireGuard Mesh, Babel | VM 3대+ | ⬜ 시작 전 | [폴더](./09-adhoc-mesh-network) |
| 10 | VPN 프로토콜 성능 비교 | IPsec(StrongSwan) vs WireGuard | VM 2대 | ⬜ 시작 전 | [폴더](./10-vpn-protocol-benchmark) |

상태 표기: ⬜ 시작 전 · 🟡 진행 중 · ✅ 완료 (PR 머지 시 갱신)

## ☁️ 인프라

- GCP Compute Engine 기반, Linux(Ubuntu) VM에서 실습
- 인스턴스 구성과 비용 메모는 [`infra/INSTANCES.md`](./infra/INSTANCES.md)에 기록 (VM 스펙, 리전, 실습별 필요 대수, 정리 여부)
- 실습이 끝난 VM은 즉시 삭제하거나 중지하여 비용을 관리합니다.

## 📂 디렉토리 구조

```
linux-kernel-networking/
├── README.md                          # (현재 파일) 전체 개요
├── CLAUDE.md                          # 작업 규칙 (커밋/브랜치/리뷰 컨벤션)
├── infra/
│   └── INSTANCES.md                   # VM 구성 및 비용 메모
├── 01-k8s-service-from-scratch/
│   ├── README.md                      # 개념 정리, 다이어그램
│   ├── PROGRESS.md                    # 트러블슈팅 로그, 키워드, TIL
│   ├── scripts/                       # 실습 스크립트
│   └── diagrams/                      # 구조도
├── 02-l4-l7-loadbalancer-comparison/
├── 03-dns-coredns-deepdive/
├── 04-tunneling-overlay-network/
├── 05-mtu-fragmentation/
├── 06-conntrack-nat-table/
├── 07-ebpf-cni-future/
├── 08-sysctl-tcp-tuning/
├── 09-adhoc-mesh-network/
└── 10-vpn-protocol-benchmark/
```

## 📚 주제별 한 줄 요약

1. **K8s Service 가상 구현**: ClusterIP/NodePort를 iptables와 IPVS로 직접 재현하고, 서비스 수천 개 환경에서 O(N) vs O(1) 성능 차이를 검증합니다.
2. **L4/L7 로드밸런서 비교**: 커널 레벨 IPVS와 유저스페이스 HAProxy/Nginx를 같은 트래픽으로 비교해 구조적 차이를 수치로 증명합니다.
3. **DNS & CoreDNS**: Iterative/Recursive 조회를 직접 추적하고, K8s `ndots:5` 기본값이 일으키는 성능 저하를 패킷 레벨에서 증명합니다.
4. **터널링 & 오버레이**: VXLAN으로 VM 간 L2 터널을 직접 구축하고, CNI가 Pod 간 패킷을 캡슐화하는 과정을 tcpdump로 바이트 단위 분석합니다.
5. **MTU 트러블슈팅**: 터널링 환경에서 흔히 발생하는 패킷 파편화 장애를 의도적으로 재현하고 MSS Clamping으로 해결합니다.
6. **Conntrack & NAT 테이블 한계**: `nf_conntrack` 테이블이 가득 차 신규 연결이 드롭되는 실무 장애를 재현하고 한계를 측정합니다.
7. **eBPF 기반 네트워크 분석**: iptables의 구조적 한계를 짚고, XDP로 커널 초입에서 패킷을 드롭하는 DDoS 방어를 구현합니다.
8. **TCP 커널 파라미터 튜닝**: `somaxconn`, `tcp_tw_reuse` 등을 조정하며 대량 동시접속/TIME_WAIT 고갈 상황을 재현하고 해결합니다.
9. **Ad-hoc & 메시 네트워크**: WireGuard Mesh로 노드를 연결하고, 노드 장애 시 경로가 스스로 우회하는 과정과 Convergence Time을 측정합니다.
10. **VPN 프로토콜 성능 비교**: IPsec과 WireGuard 터널을 각각 구축해 CPU 사용량 대비 처리량/지연시간을 비교합니다.

---

## 🔗 Reference

각 주제 폴더의 `README.md`에 상세 레퍼런스와 학습 키워드를 정리합니다.
