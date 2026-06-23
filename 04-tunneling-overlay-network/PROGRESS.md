# PROGRESS: 터널링 & 오버레이 네트워크

## 진행 로그

### 2026-06-22

**한 일**
- GCP asia-northeast3-a에 lab-vm-02(e2-standard-2, 10.178.0.3) 생성
- lab-vm-01/02 양쪽에 vxlan0(VNI=100, dstport=4789) 설정, 터널 IP 192.168.100.1/2 할당
- tcpdump로 VXLAN 캡슐화 구조 관찰 (외부 UDP + 내부 ICMP/ARP)
- K8s Flannel 시뮬레이션: pod 네임스페이스(pod-vm1/2) + veth pair + 크로스-노드 라우팅
- pod-vm1(10.244.0.2) → pod-vm2(10.244.1.2) pod 간 ping 성공 (TTL=62 확인)

**배운 것 (TIL)**
- VXLAN MTU는 커널이 자동으로 물리 MTU − 50으로 설정한다. GCP ens4(1460) → vxlan0(1410). 직접 계산할 필요 없이 `ip link show vxlan0`으로 확인 가능.
- ARP(L2 브로드캐스트)도 VXLAN으로 캡슐화된다. `remote`로 상대 VTEP IP를 지정하면 유니캐스트 방식으로 전달된다. 실제 Flannel은 `L2miss`/`L3miss` netlink 이벤트로 동적으로 FDB(Forwarding Database)를 업데이트한다.
- pod-vm1 → pod-vm2 ping에서 TTL=62가 나오는 이유: pod(TTL=64) → 호스트 라우팅(−1=63) → VXLAN(물리 네트워크) → 대상 호스트 라우팅(−1=62) → pod 수신. 2번의 라우팅 홉.
- `ip netns exec`는 반드시 `sudo`가 필요하다. 일반 사용자가 실행하면 "Operation not permitted" 발생.
- VXLAN VNI는 24비트(0~16,777,215)로 기존 VLAN 12비트(0~4,095)보다 훨씬 많은 가상 네트워크를 지원한다. 대규모 멀티테넌트 환경(클라우드 데이터센터)에서 필수.
- GCP 기본 firewall 정책은 동일 VPC 내 VM 간 모든 포트(UDP 4789 포함)를 허용한다. 별도 방화벽 규칙 없이 VXLAN이 동작했다.

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `ip netns exec pod-vm1 ip addr show veth0` → "Operation not permitted" | `sudo` 없이 `ip netns exec` 실행 | `sudo ip netns exec pod-vm1 ...` |

---

## 학습 키워드 누적 정리

**VXLAN 기본**
- `ip link add NAME type vxlan id VNI remote REMOTE dstport 4789 dev PHY` — VTEP 생성
- VNI (VXLAN Network Identifier) — 24비트, 최대 16,777,215개 가상 네트워크
- VTEP (VXLAN Tunnel Endpoint) — 캡슐화/해제를 담당하는 커널 가상 인터페이스
- dstport 4789 — IANA 표준 VXLAN UDP 포트 (구버전은 8472 사용)
- `flags [I] (0x08)` — 유효한 VXLAN 프레임 표시 비트

**VXLAN 패킷 구조**
- 오버헤드: 외부IP(20) + UDP(8) + VXLAN(8) + 내부Ethernet(14) = **50바이트**
- MTU 자동 계산: `vxlan0 mtu = 물리 mtu − 50`
- 이중 IP 헤더: 외부(물리 VM IP) + 내부(pod/터널 IP)

**K8s CNI 연관**
- Flannel VXLAN 모드: `flannel.1` VTEP, `--pod-cidr`로 노드당 서브넷 자동 할당
- Calico VXLAN 모드: IP-in-IP 또는 VXLAN 선택 가능
- FDB (Forwarding Database): VTEP MAC-to-IP 매핑 테이블 (`bridge fdb show`)
- `L2miss` / `L3miss` netlink 이벤트: 동적 FDB 갱신 메커니즘

**ip 명령**
- `ip link add type vxlan` — VXLAN 인터페이스 생성
- `ip netns add/exec/del` — 네트워크 네임스페이스 관리
- `ip link add type veth peer name` — veth pair 생성
- `ip link set DEVICE netns NS` — 인터페이스를 네임스페이스로 이동
- `ip route add SUBNET via NEXTHOP dev DEV` — 정적 경로 추가
- `sysctl -w net.ipv4.ip_forward=1` — IP 포워딩 활성화

---

## 막혔던 점 / 다음에 더 파볼 것

- **FDB 동적 갱신**: 이번 실습은 `remote`로 상대방 VTEP을 정적으로 지정했다. 실제 Flannel은 `L2miss`/`L3miss` 이벤트를 사용해 FDB를 동적으로 관리한다. `bridge fdb show dev vxlan0`으로 현재 상태를 보고, `ip monitor neigh`로 학습 이벤트를 관찰하는 추가 실험이 가능하다.
- **GRE/IP-in-IP 비교**: VXLAN 대신 GRE나 IP-in-IP를 쓰면 오버헤드가 다르다. `ip link add type gretap` 또는 `type ipip`으로 동일한 실험을 반복해 캡슐화 크기를 비교해볼 수 있다.
- **MTU 문제 재현**: 05번 주제에서 VXLAN 오버헤드로 인한 패킷 단편화 장애를 의도적으로 재현할 예정. 이번 환경(lab-vm-01/02)을 그대로 재사용한다.
