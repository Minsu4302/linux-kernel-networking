# PROGRESS: MTU 트러블슈팅 & 패킷 파편화

## 진행 로그

### 2026-06-23

**한 일**
- 04번 VXLAN 환경(lab-vm-01, lab-vm-02) 재활용
- ICMP DF 비트로 MTU 경계 1바이트 단위 확인 (1382 성공 / 1383 실패)
- tcpdump로 TCP SYN/SYN-ACK MSS 협상 관찰 (mss 1370 양방향 확인)
- iptables mangle --set-mss 500으로 MSS 강제 축소 → SYN mss 500 실측
- --clamp-mss-to-pmtu 규칙으로 Path MTU 기반 자동 클램핑 확인

**배운 것 (TIL)**
- VXLAN MTU는 커널이 `물리 MTU − 50`으로 자동 계산. GCP에서 vxlan0 MTU를 물리 MTU 이상으로 올리려 하면 `RTNETLINK answers: Invalid argument`
- TCP MSS = vxlan0 MTU(1410) − IP헤더(20) − TCP헤더(20) = **1370**. SYN 패킷에서 협상되어 연결 수명 동안 고정됨
- MSS Clamping은 SYN 패킷의 MSS **옵션 필드를 재기록**하는 것. 실제 전송이 아닌 협상 단계에 개입
- `--set-mss N`: 클라이언트 SYN의 MSS가 N으로 덮어쓰이고, 서버가 더 큰 값을 제안해도 양쪽은 min(N, 서버MSS)를 사용
- nc는 host에서 직접 패킷을 생성하므로 FORWARD 체인을 거치지 않음. host originate 패킷에는 OUTPUT 체인에 규칙을 달아야 함
- FORWARD는 다른 인터페이스로 라우팅될 때(예: pod namespace → vxlan0) 적용됨

**트러블슈팅**

| 증상 | 원인 | 해결 |
|------|------|------|
| `sudo ip link set vxlan0 mtu 1500` → `RTNETLINK answers: Invalid argument` | GCP 커널이 vxlan0 MTU를 물리 MTU(1460) − 오버헤드(50) = 1410 이상으로 올리는 것을 차단 | MTU Black Hole 직접 재현 대신 EMSGSIZE + MSS Clamping 실습으로 전환 |
| `--set-mss` 규칙이 nc 연결에 적용 안 됨 | FORWARD 체인에만 추가했는데, nc는 로컬 생성 패킷이므로 OUTPUT 체인이 대상 | OUTPUT 체인에 규칙 추가 |

---

## 학습 키워드 누적 정리

- `ping -M do -s N TARGET` — DF 비트 on, 페이로드 N바이트 ICMP 전송
- `EMSGSIZE` — DF 설정 패킷이 MTU 초과 시 커널이 반환하는 오류 번호 (errno 90)
- `tcpdump 'tcp[13] & 2 != 0'` — BPF 필터로 SYN 비트 패킷만 캡처
- `iptables -t mangle -A CHAIN -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss N`
- `iptables -t mangle -A CHAIN -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu`
- MSS = MTU − 40 (기본 IP+TCP 헤더 합산. 옵션 없을 때)
- PMTUD: DF 패킷이 중간 홉에서 드롭되면 라우터가 ICMP type3 code4(Fragmentation Needed) 반환
- ICMP Black Hole: ICMP unreachable을 방화벽이 차단 → PMTUD 작동 불가 → TCP 연결 stall
- K8s CNI(Flannel/Calico VXLAN 모드): `--clamp-mss-to-pmtu`를 FORWARD 체인에 자동 적용

## 막혔던 점 / 다음에 더 파볼 것

- GCP 커널 패치로 MTU Black Hole을 완전 재현하지 못했다. 재현하려면 iptables로 ICMP Fragmentation Needed를 DROP하고 MTU 초과 패킷을 보내야 하는데, GCP에서는 vxlan0 MTU를 올릴 수 없어 `ping -s 1411`이 커널에서 바로 거부됨
- Jumbo Frame 지원 환경(물리 MTU 9000)에서 VXLAN 오버헤드를 감안한 MSS 계산 차이 실험 여지 있음
- `ip tcp_metrics` 캐시로 PMTUD가 학습한 경로 MTU 확인하는 방법 미확인
