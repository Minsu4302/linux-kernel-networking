# PROGRESS: Ad-hoc & 메시 네트워크

## 진행 로그

### 2026-06-25

**한 일**
- GCP lab-vm-03 신규 생성 (10.178.0.4, asia-northeast3-a)
- 3대 VM에 wireguard, wireguard-tools 설치
- 각 VM에서 키 쌍 생성 (`wg genkey | tee privatekey | wg pubkey > pubkey`)
- wg0.conf 작성 + `wg-quick up wg0`으로 Full Mesh 구성
- 6개 방향 ping 검증 (3 엣지 × 양방향) → 전부 0% 패킷 손실
- 장애 시뮬레이션: vm-02 wg0 down → vm-01에서 감지 시간 측정
- vm-02 복구(`wg-quick up`) 후 재연결 확인

**배운 것 (TIL)**
- WireGuard는 "silent until spoken to" — 트래픽이 없으면 핸드셰이크를 하지 않아 `wg show`에 `latest handshake`가 없어도 정상
- 첫 ping을 보내는 순간 Initiation → Response → 데이터 순으로 핸드셰이크가 완료됨
- GCP 동일 리전 VM 간 WireGuard 암호화 터널 RTT: ~0.8~1.2ms (물리 레이턴시보다 미미하게 높음)
- `wg-quick`이 자동으로 MTU를 1380으로 설정함: GCP MTU 1460 - WireGuard 헤더(UDP 8 + IP 20 + WireGuard 32 + Poly1305 16 = ~80바이트) = 1380
- Full Mesh에서 특정 노드 다운 시 나머지 노드 간 독립 터널은 영향 없음

**트러블슈팅**

| 증상 | 원인 | 해결 |
|------|------|------|
| `cd /etc/wireguard: Permission denied` | `/etc/wireguard`는 root 소유 700 디렉토리 | `cd` 없이 절대 경로로 `sudo tee /etc/wireguard/...` 직접 사용. 키 생성 자체는 `sudo tee`로 정상 완료 |
| `wg show` 초기에 `latest handshake` 없음 | WireGuard는 on-demand 핸드셰이크 — 실제 패킷이 없으면 터널을 열지 않음 | 첫 ping 전송 후 `wg show` 재실행하면 `latest handshake` 표시됨 |

---

## 학습 키워드 누적 정리

- **WireGuard**: Linux 5.6+ 커널 내장 VPN. ~4000줄 코드, ChaCha20-Poly1305 + Curve25519 ECDH
- **Full Mesh**: N 노드 간 N*(N-1)/2 개의 독립 P2P 터널. 단일 노드 장애 내성
- **Hub-and-Spoke**: 중앙 허브를 통한 연결. 설정 단순하나 Hub SPOF
- **Convergence Time**: 장애 발생 ~ 감지까지의 시간. 이번 실험: ~2초 (ping 1초 타임아웃 + 1초 슬립)
- **PersistentKeepalive**: WireGuard 옵션. 설정(초) 마다 keepalive 패킷 전송 → NAT 홀 유지 + 능동 장애 감지. 미설정 시 silent until spoken to
- **wg-quick**: WireGuard 설정 파일(`wg0.conf`) 기반 인터페이스 관리 wrapper
- **AllowedIPs**: WireGuard의 라우팅 테이블 역할. 해당 IP 대역의 패킷만 이 peer로 암호화하여 전송
- **Endpoint**: peer의 물리 주소(IP:port). 한쪽만 설정해도 양방향 통신 가능 (Roaming 지원)
- **ChaCha20-Poly1305**: WireGuard의 AEAD 암호화. AES-GCM 대비 하드웨어 가속 없는 환경에서 빠름
- **Noise Protocol Framework**: WireGuard가 채택한 핸드셰이크 프레임워크. Forward Secrecy 보장

## 막혔던 점 / 다음에 더 파볼 것

- **Babel 프로토콜**: Full Mesh가 N=10+ 이상이면 peer 관리가 폭발적으로 늘어남. babeld/bird로 동적 라우팅을 추가하면 Hub-and-Spoke 없이도 자동 경로 수렴 가능 — 다음에 실습해볼 것
- **PersistentKeepalive 실험**: keepalive 없을 때 vs 25초 설정 시 장애 감지 시간 차이를 정량적으로 비교
- **wireguard-go**: userspace WireGuard 구현. 커널 모듈 없이 컨테이너 내에서도 실행 가능한데 성능 차이가 어느 정도인지 측정해보고 싶음
