# PROGRESS: VPN 프로토콜 성능 비교

## 진행 로그

### 2026-06-25

**한 일**
- lab-vm-01, lab-vm-02에 iperf3, sysstat, strongswan 설치
- Baseline 측정: 3.99 Gbps, ping avg 0.317ms, CPU 31.5%
- WireGuard Topic 09 키 재사용, wg0 재기동 후 측정: 1.51 Gbps, 0.805ms, CPU 67.4%
- GCP 방화벽 ESP 허용 규칙 추가 후 IPsec 측정: 0.88 Gbps, 0.467ms, CPU 52.6%
- 결과 분석: WireGuard가 처리량 우위, IPsec이 지연시간 우위

**배운 것 (TIL)**
- GCP VPC default "allow-internal" 규칙은 TCP/UDP/ICMP만 허용 — ESP(protocol 50)는 별도 방화벽 규칙 필요
- WireGuard는 softirq(10.1%) 레벨에서 패킷을 처리해 고부하에 효율적
- IPsec은 XFRM 프레임워크 오버헤드로 패킷당 컨텍스트 전환이 많아 처리량 한계가 낮음
- AES-NI 하드웨어 가속이 있어도 XFRM 오버헤드 때문에 WireGuard(소프트웨어 ChaCha20)보다 처리량이 낮음
- 단일 패킷 지연(ping)은 AES-NI 덕분에 IPsec이 더 낮음 — 고부하 처리량과는 다른 지표
- IPsec transport mode는 IP 헤더를 보존하고 페이로드만 암호화 (tunnel mode는 IP 헤더까지 캡슐화)

**트러블슈팅**

| 증상 | 원인 | 해결 |
|------|------|------|
| `iperf3: error - unable to send control message: Bad file descriptor` | lab-vm-02에서 iperf3 서버가 미실행 상태 | lab-vm-02에서 `iperf3 -s` 재실행 후 재시도 |
| IPsec 설정 후 ping 100% 패킷 손실 | GCP VPC 방화벽이 ESP(IP proto 50)를 기본 차단 | Cloud Shell에서 `gcloud compute firewall-rules create allow-ipsec-esp --allow=esp` 추가 |

---

## 학습 키워드 누적 정리

- **XFRM**: Linux 커널의 IPsec 프레임워크. SA(Security Association) 관리, 정책 조회, 암호화 처리를 담당
- **ESP (Encapsulating Security Payload)**: IPsec의 데이터 암호화 프로토콜. IP protocol 50
- **IKEv2 (Internet Key Exchange v2)**: IPsec SA 협상 프로토콜. UDP 500/4500 사용
- **transport mode**: 페이로드만 암호화, IP 헤더 보존. 호스트 간 직접 통신에 사용
- **tunnel mode**: IP 패킷 전체를 캡슐화. 게이트웨이-게이트웨이 Site-to-Site VPN에 사용
- **AES-NI**: x86 AES 하드웨어 가속 명령어 세트. AES-256-GCM을 소프트웨어 대비 수배 빠르게 처리
- **ChaCha20-Poly1305**: WireGuard의 AEAD 암호화. ARM/IoT 등 AES-NI 없는 환경에서 빠름
- **softirq**: 네트워크 인터럽트 하위 처리. WireGuard는 이 레벨에서 직접 패킷 처리 → 고부하 효율↑
- **PSK (Pre-Shared Key)**: 사전 공유 키 방식 인증. 실무에서는 인증서(PKI) 기반 권장

## 막혔던 점 / 다음에 더 파볼 것

- **AES-NI 확인**: `grep aes /proc/cpuinfo`로 GCP VM의 AES-NI 지원 여부 확인 후 분석에 반영하지 못함
- **IPsec tunnel mode 비교**: transport mode와 tunnel mode의 처리량 차이 (오버헤드 비교)
- **단일 스트림 비교**: `-P 1`로 단일 스트림 시 CPU 병목이 아닌 암호화 속도 차이를 더 명확히 볼 수 있을 것
- **WireGuard userspace(wireguard-go) 비교**: 커널 모듈 vs 유저스페이스 구현의 처리량 차이
