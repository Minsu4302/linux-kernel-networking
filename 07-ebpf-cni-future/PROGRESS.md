# PROGRESS: eBPF 기반 네트워크 분석

## 진행 로그

### 2026-06-24

**한 일**
- clang/llvm/libbpf-dev 설치, XDP C 프로그램 2개 작성·컴파일
- `pkt_counter.c`: BPF ARRAY 맵으로 프로토콜별 수신 패킷 카운팅, bpftool로 실시간 조회
- `drop_icmp.c`: ICMP를 XDP_DROP, TCP/UDP는 XDP_PASS → ping 100% 드롭, SSH/curl 정상
- XDP 언로드 후 ping 즉시 복구 확인

**배운 것 (TIL)**
- BPF 프로그램 컴파일 시 `-g` 없으면 BTF 정보가 없어 커널 6.x에서 로드 거부됨 (`libbpf: BTF is required`)
- GCP virtio-net은 native XDP 미지원 (`any_header_sg` 기능 없음) → `xdpgeneric` 사용. 실무 클라우드 환경에서 XDP 모드 확인 필수
- XDP는 **ingress 전용**: 송신 패킷은 XDP를 거치지 않음. 패킷 카운터에서 echo reply(수신)만 카운트, echo request(송신)는 제외
- `__sync_fetch_and_add`: BPF 내 SMP-safe atomic 카운터 증가. BPF verifier가 일반 `+=`를 race condition 위험으로 거부할 수 있어 필요
- XDP_DROP은 SKB 할당 없이 드롭 → DDoS 트래픽에 대해 CPU 소모 최소화
- BPF verifier: 로드 시 무한루프·OOB 접근 검사. verifier를 통과해야만 커널에 로드됨

**트러블슈팅**

| 증상 | 원인 | 해결 |
|------|------|------|
| `libbpf: BTF is required, but is missing or corrupted` | clang 컴파일 시 `-g` 미지정 → BTF 섹션 없음 | `clang -O2 -g -target bpf` |
| `virtio_net: XDP expects header/data in single page, any_header_sg required` | GCP virtio-net driver가 native XDP 지원 안 함 | `xdpgeneric` 모드로 로드 |

---

## 학습 키워드 누적 정리

- `clang -O2 -g -target bpf -I/usr/include/x86_64-linux-gnu -c prog.c -o prog.o`
- `ip link set dev ens4 xdpgeneric obj prog.o sec xdp` — generic 모드 XDP 로드
- `ip link set dev ens4 xdpgeneric off` — XDP 언로드
- `bpftool prog show` — 로드된 BPF 프로그램 목록 (타입, ID, 크기, JIT 여부)
- `bpftool map show` / `bpftool map lookup id N key HEX` — 맵 조회
- `SEC("xdp")` — XDP 훅 포인트 마킹. libbpf가 이 이름으로 프로그램 찾음
- `XDP_PASS / XDP_DROP` — verdict. DROP은 SKB 없이 즉시 드롭
- `BPF_MAP_TYPE_ARRAY` — 고정 배열 맵. key=index, 초기값=0
- `bpf_map_lookup_elem(&map, &key)` — BPF 내 맵 조회 헬퍼
- `__sync_fetch_and_add(ptr, 1)` — BPF 내 atomic 증가
- BTF(BPF Type Format) — 타입 정보 메타데이터. `-g`로 생성, 최신 커널 로드 시 필수
- XDP 3모드: native(드라이버) > generic(SKB) > offloaded(HW)

## 막혔던 점 / 다음에 더 파볼 것

- GCP native XDP 미지원으로 generic 모드만 가능. native 모드 성능 차이는 벤치마크 불가
- BPF_MAP_TYPE_PERCPU_ARRAY: CPU별 카운터로 __sync_fetch_and_add 없이도 race-free. 추후 비교 실험 여지
- XDP_TX: 패킷을 수정해 같은 인터페이스로 즉시 반송 (rate limiting, SYN cookie 등). 미실습
- `bpftrace`로 kprobe/uprobe 붙여 커널 함수 호출 추적하는 실험 미시도
- Cilium이 BPF 맵으로 ClusterIP DNAT를 처리하는 구체적 맵 구조 탐색 여지 있음
