# PROGRESS: Cilium CNI & Hubble 관찰성

## 진행 로그

### 2026-06-30

**한 일**
- K8s 1.30 클러스터 구성 (kubeadm, 3노드: vm-01 control plane / vm-02, vm-03 worker)
- Cilium 1.15.5 설치: kube-proxy 완전 대체(kubeProxyReplacement=true) + Hubble relay/metrics 활성화
- Star Wars 데모 앱 배포 (deathstar, tiefighter, xwing)
- CiliumNetworkPolicy L7 정책 적용 및 허용/차단 검증
- Hubble CLI로 L7 HTTP 플로우 실시간 관찰

**실험 결과**

| 시나리오 | 정책 전 | 정책 후 | 차단 레이어 |
|----------|---------|---------|------------|
| tiefighter → POST /v1/request-landing | HTTP 200 | HTTP 200 | — (허용) |
| tiefighter → PUT /v1/exhaust-port | "deathstar exploded" | **HTTP 403** | **L7** (Envoy 거부) |
| xwing → POST /v1/request-landing | HTTP 200 | **타임아웃(DROP)** | **L3/L4** (BPF DROP) |

**Hubble 플로우 로그 (핵심 발췌)**

```
tiefighter → deathstar  POST /v1/request-landing  http-request FORWARDED
tiefighter ← deathstar  POST /v1/request-landing  http-response FORWARDED HTTP/1.1 200 4ms

tiefighter → deathstar  PUT  /v1/exhaust-port      http-request DROPPED
tiefighter ← deathstar  PUT  /v1/exhaust-port      http-response FORWARDED HTTP/1.1 403 0ms
```

→ xwing 트래픽은 L7 플로우에 **아예 미등장** (BPF에서 이미 DROP, Envoy까지 미도달)

**배운 것 (TIL)**

- **kube-proxy 없는 K8s**: `kubeadm init --skip-phases=addon/kube-proxy` → iptables에 Service DNAT 규칙 없음. Cilium Agent가 BPF LB map으로 ClusterIP 처리
- **Cilium L7 정책 차단 2가지 방식**:
  - org=alliance(xwing) → L3/L4 BPF DROP. 패킷이 Envoy에 도달하지 않음 → HTTP 응답 없음(타임아웃)
  - org=empire + 잘못된 경로(PUT /v1/exhaust-port) → Envoy가 L7 검사 후 **HTTP 403 반환**. 연결은 L4에서 허용되고 응답 코드로 거부
- **Hubble L7 관찰성**: BPF 데이터 경로에서 이벤트 수집 → L7 HTTP 요청/응답, 허용/차단 여부, 응답 코드, 레이턴시(4ms, 0ms)가 Pod 이름과 함께 기록됨
- **Connected Nodes: 3/3**: Hubble Relay가 모든 노드의 Agent에서 플로우를 집계. 클러스터 전체 트래픽 단일 뷰
- **L3/L4 vs L7 차단 시각화**: iptables 시대에는 이 구분이 불가능했음. Hubble은 어느 레이어에서 차단됐는지 즉시 확인 가능

**트러블슈팅**

| 증상 | 원인 | 해결 |
|------|------|------|
| kubernetes.list Malformed entry | `echo` 백슬래시 줄바꿈이 2줄로 저장됨 | 한 줄로 수정 후 `tee` |
| `W0630 No kubeproxy.config` | kube-proxy 미설치 (의도적) | 정상 경고, 무시 |
| kubeadm init NotReady | Cilium 미설치 상태 (정상) | `04-install-cilium.sh` 실행 후 Ready |

---

## 학습 키워드 누적 정리

- `Cilium` — eBPF 기반 K8s CNI. kube-proxy 대체, L7 정책, 관찰성 통합
- `kubeProxyReplacement=true` — iptables Service 규칙 없이 BPF LB map으로 ClusterIP/NodePort 처리
- `--skip-phases=addon/kube-proxy` — kubeadm init 시 kube-proxy DaemonSet 설치 생략
- `CiliumNetworkPolicy` — K8s NetworkPolicy 상위 호환. HTTP method/path/header 단위 L7 제어
- `Hubble` — Cilium 내장 관찰성 레이어. BPF 이벤트를 gRPC 스트림으로 수집
- `Hubble Relay` — 클러스터 전체 노드의 플로우 집계 (per-node Agent → Relay → CLI/UI)
- `hubble observe --type l7` — L7 HTTP/DNS/Kafka 플로우 필터링
- `cilium hubble port-forward` — Relay를 localhost:4245로 포워드
- `Envoy` — Cilium이 L7 정책 집행에 사용하는 내장 프록시. HTTP 403을 직접 생성
- `BPF LB map` — ClusterIP 서비스를 O(1)로 처리하는 해시맵 (iptables DNAT 대체)
- `EndpointSelector` — CiliumNetworkPolicy에서 Pod 레이블로 정책 대상 선택
- `Connected Nodes: 3/3` — Hubble이 전체 클러스터 노드와 연결됨을 확인

## 막혔던 점 / 다음에 더 파볼 것

- Hubble UI (포트포워드 + 브라우저)로 그래피컬 플로우 시각화
- Cilium BGP Control Plane으로 MetalLB 없이 LoadBalancer IP 광고 (13번 BGP와 연동)
- Cilium Cluster Mesh로 멀티 클러스터 간 서비스 디스커버리
- eBPF 기반 네트워크 정책의 CPU 오버헤드 측정 (12번 iptables O(N) 비교와 연결)
