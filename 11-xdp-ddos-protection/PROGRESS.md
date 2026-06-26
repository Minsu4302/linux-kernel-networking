# PROGRESS: XDP 기반 DDoS 방어 시뮬레이션

## 진행 로그

### 2026-06-26

**한 일**
- XDP BPF 프로그램(`xdp_drop.c`) 작성: BPF_MAP_TYPE_HASH 블랙리스트 + 카운터
- clang `-g` + BTF 섹션 포함 빌드 (`01-build.sh`)
- 3조건(Baseline / iptables / XDP) 벤치마크 실행 및 수치 수집
- 결과 비교 스크립트(`06-compare.sh`) 작성 및 bash 구문 버그 수정

**벤치마크 결과 (lab-vm-01 → lab-vm-02, hping3 --flood ICMP)**

| 조건 | pps (추정) | %sys | %softirq | %idle | CPU 사용률 |
|------|-----------|------|----------|-------|-----------|
| Baseline (필터 없음) | ~4,310 | 0.0 | 0.0 | 98.7 | 1.3% |
| iptables DROP | ~141,600 | 0.0 | 0.0 | 99.3 | 0.7% |
| XDP DROP (xdpgeneric) | ~149,300 | 0.0 | 0.1 | 99.3 | 0.7% |

- XDP가 iptables보다 **~5% 더 많은 패킷 처리** (2,990,875 vs 2,832,000 / 20초)
- CPU는 두 방법 모두 0.7%로 동일 → xdpgeneric 모드의 한계 (SKB 생성 후 드롭)
- Baseline CPU(1.3%)가 가장 높은 이유: ICMP echo reply 생성 오버헤드

**배운 것 (TIL)**
- **xdpgeneric vs native XDP**: GCP virtio-net은 native XDP 미지원 → SKB 생성 후 드롭. 프로덕션(Intel i40e, Mellanox mlx5)에서는 SKB 생성 전 드롭으로 차이가 훨씬 극적
- **BPF_MAP_TYPE_HASH**: O(1) 블랙리스트 조회. iptables의 O(N) 선형 탐색 대비 규칙 수가 늘어도 속도 유지
- **bpftool map update**: hex key로 IP를 직접 BPF 맵에 삽입하는 런타임 정책 갱신
- **Baseline pps가 낮은 이유**: 필터 없이 vm-02가 ICMP reply를 모두 생성하면 backpressure 발생 → hping3 실효 속도 감소. DROP 시 reply 없어지면 flood 속도 폭발적 증가
- **XFRM 정책 충돌**: strongSwan `auto=start` 설정이 VM 재시작 시 XFRM 정책을 자동 설치 → 동일 IP 쌍의 일반 ICMP가 ESP 터널 요구로 드롭됨

**트러블슈팅**

| 증상 | 원인 | 해결 |
|------|------|------|
| vm-01 → vm-02 ping 100% packet loss | Topic 10 strongSwan의 XFRM 정책이 VM 재시작 후에도 남아 있어 ICMP를 ESP 터널로 강제 라우팅 | `sudo systemctl stop strongswan; sudo ip xfrm policy flush; sudo ip xfrm state flush` |
| hping3 --flood ICMP가 tcpdump에 안 잡힘 | 위 XFRM 정책으로 패킷이 커널에서 드롭됨 (GCP 필터링 아님) | 위와 동일 |
| `06-compare.sh` bash 구문 오류 | `for label file in ...` 은 bash에서 유효하지 않음 | `while IFS=: read -r label file` + heredoc 방식으로 수정 |
| XDP 로드 시 BTF 오류 | clang 컴파일 시 `-g` 플래그 누락 → BTF 섹션 없음 | `clang -O2 -g -target bpf ...` 로 BTF 포함 빌드 |

---

## 학습 키워드 누적 정리

- `XDP (eXpress Data Path)` — NIC 드라이버 레벨 패킷 처리 프레임워크
- `xdpgeneric` — SKB 모드 XDP, 드라이버 미지원 환경에서 fallback
- `native XDP` — SKB 생성 전 처리, Intel i40e / Mellanox mlx5 지원
- `BPF_MAP_TYPE_HASH` — O(1) 해시맵, XDP blocklist 구현에 사용
- `BPF_MAP_TYPE_ARRAY` — 고정 크기 배열 맵, 글로벌 카운터에 사용
- `BTF (BPF Type Format)` — 커널 6.x XDP 로드에 필수, `-g` 플래그로 생성
- `XDP_DROP / XDP_PASS` — BPF 반환값: 즉시 폐기 / 커널 스택으로 전달
- `bpftool map update` — 런타임 BPF 맵 조작 (정책을 재컴파일 없이 변경)
- `XFRM` — Linux 커널 IPsec 정책/상태 프레임워크
- `ip xfrm policy flush` — XFRM 정책 전체 제거

## 막혔던 점 / 다음에 더 파볼 것

- native XDP 지원 NIC(i40e, mlx5)에서 동일 실험 시 CPU 차이가 얼마나 극적으로 나는지 확인
- XDP_TX 를 이용한 rate limiting (드롭이 아닌 속도 제한) 구현
- eBPF ring buffer로 실시간 드롭 로그 스트리밍
