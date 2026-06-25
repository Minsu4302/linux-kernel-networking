# 10. VPN 프로토콜 성능 비교 — IPsec vs WireGuard

## 왜 이 주제인가

Topic 09에서 WireGuard Mesh를 직접 구성했다. 그렇다면 IPsec과 비교했을 때 실제 성능 차이는 얼마나 될까? "WireGuard가 빠르다"는 말은 흔하지만 구체적인 수치 없이는 면접에서 설득력이 없다. 동일 VM, 동일 조건에서 세 가지 측정값(처리량·지연·CPU)을 직접 측정해 구조적 차이를 수치로 증명한다.

---

## 아키텍처

```
[lab-vm-01]  ←───────────────────────────→  [lab-vm-02]
10.178.0.2                                    10.178.0.3
(iperf3 client)                           (iperf3 server)

측정 조건 1: Baseline — 물리 네트워크 직접
측정 조건 2: WireGuard — UDP 51820, ChaCha20-Poly1305, MTU 1380
측정 조건 3: IPsec  — ESP(proto 50), AES-256-GCM, transport mode, IKEv2+PSK
```

### WireGuard 패킷 경로

```
앱 데이터
  → WireGuard 드라이버 (wireguard.ko)
    → ChaCha20-Poly1305 암호화 (소프트웨어)
      → UDP 캡슐화 (port 51820)
        → 물리 NIC
```

### IPsec 패킷 경로 (transport mode)

```
앱 데이터
  → TCP/IP 스택
    → XFRM (커널 IPsec 프레임워크)
      → AES-256-GCM 암호화 (AES-NI 하드웨어 가속)
        → ESP 헤더 추가 (protocol 50)
          → 물리 NIC
```

---

## 실습 환경

| VM | 물리 IP | 역할 |
|----|---------|------|
| lab-vm-01 | 10.178.0.2 | iperf3 클라이언트 (트래픽 발신 + CPU 측정) |
| lab-vm-02 | 10.178.0.3 | iperf3 서버 (트래픽 수신) |

머신 타입: e2-standard-2 (2vCPU, 8GB RAM), GCP asia-northeast3-a

---

## 벤치마크 결과

측정 방법: `iperf3 -t 30 -P 4` (30초 × 4 병렬 스트림), `ping -c 100`, `mpstat 1 35`

### 종합 비교

| 항목 | Baseline | WireGuard | IPsec (AES-256-GCM) |
|------|:--------:|:---------:|:-------------------:|
| **처리량 (Gbps)** | **3.99** | 1.51 | 0.88 |
| **CPU 사용률** | 31.5% | 67.4% | **52.6%** |
| **Ping avg (ms)** | **0.317** | 0.805 | 0.467 |
| **Ping 오버헤드** | — | +0.49ms | **+0.15ms** |
| **TCP 재전송** | 0 | 1,540 | 977 |
| **Baseline 대비 처리량** | 100% | 37.8% | 22.1% |

> 환경: GCP e2-standard-2 (2vCPU), 동일 리전 VM 간 내부 네트워크

### CPU 세부 분석

| 구분 | %usr | %sys | %softirq | %idle |
|------|------|------|----------|-------|
| Baseline | 4.6% | 23.0% | 3.9% | 68.5% |
| WireGuard | 2.2% | 55.0% | **10.1%** | 32.7% |
| IPsec | 2.7% | **47.9%** | 2.0% | 47.4% |

---

## 분석

### 왜 WireGuard가 IPsec보다 처리량이 높은가?

**WireGuard 코드패스:**
- wireguard.ko가 softirq(네트워크 인터럽트) 컨텍스트에서 직접 패킷 처리
- softirq 10.1% — 인터럽트 레벨에서 고속으로 패킷을 처리
- XFRM 프레임워크 없이 단순 UDP 소켓으로 송수신
- 결과: 높은 CPU 소모이지만 높은 처리량

**IPsec(StrongSwan) 코드패스:**
- 커널 XFRM 프레임워크를 통한 다단계 처리 (정책 조회 → SA 매칭 → 암호화 → 전송)
- softirq 2.0% — 패킷당 컨텍스트 스위칭 오버헤드가 큼
- AES-NI 하드웨어 가속으로 암호화 자체는 빠르지만, XFRM 오버헤드가 병목
- 결과: 낮은 CPU이지만 낮은 처리량 (처리량 vs. 처리 복잡도의 트레이드오프)

### 왜 IPsec이 ping 지연은 더 낮은가?

- 단일 패킷은 AES-NI로 매우 빠르게 암호화 → +0.15ms
- WireGuard의 ChaCha20은 소프트웨어 암호화 → +0.49ms
- 고부하 시에는 XFRM 오버헤드가 드러나 처리량에서 역전됨

### GCP 환경 특이사항

- **WireGuard**: UDP 51820 — GCP default "allow-internal" 규칙으로 통과
- **IPsec**: ESP (protocol 50) — GCP 방화벽에서 기본 차단 → **별도 방화벽 규칙 필요**

```bash
gcloud compute firewall-rules create allow-ipsec-esp \
  --network=default --allow=esp --source-ranges=10.178.0.0/20
```

---

## 프로토콜 특성 비교

| 특성 | WireGuard | IPsec (StrongSwan) |
|------|-----------|-------------------|
| 커널 통합 | 5.6+ 내장 | XFRM 프레임워크 (오래됨) |
| 암호화 | ChaCha20-Poly1305 (SW) | AES-256-GCM (HW AES-NI) |
| 키 교환 | Noise Protocol (자동) | IKEv2 (복잡, 유연) |
| 설정 복잡도 | 낮음 (pubkey 교환) | 높음 (Phase1/Phase2) |
| PKI 지원 | ❌ | ✅ (인증서 기반 가능) |
| 감사 가능성 | ✅ (~4000줄) | ❌ (수십만 줄) |
| 방화벽 통과 | 쉬움 (UDP) | 어려움 (ESP, UDP 500/4500) |
| 기업 표준 | 성장 중 | 오랜 표준 (FIPS 인증) |

### 언제 무엇을 선택하는가

- **WireGuard 선택**: 개발자 인프라, K8s CNI, VPN 게이트웨이, 성능 중시, 설정 단순화
- **IPsec 선택**: 기업 규정 준수(FIPS), 레거시 장비 연동, Site-to-Site, 정밀한 암호화 협상 필요

---

## 스크립트 목록

| 파일 | 설명 | 실행 노드 |
|------|------|---------|
| `01-install-deps.sh` | iperf3, sysstat, strongswan 설치 | 전체 |
| `02-baseline-bench.sh` | VPN 없는 기본 처리량/지연 측정 | vm-01 |
| `03-wireguard-bench.sh` | WireGuard 터널 처리량/지연 측정 | vm-01 |
| `04-ipsec-setup-vm01.sh` | StrongSwan IKEv2 설정 (vm-01) | vm-01 |
| `05-ipsec-setup-vm02.sh` | StrongSwan IKEv2 설정 (vm-02) | vm-02 |
| `06-ipsec-bench.sh` | IPsec 터널 처리량/지연 측정 | vm-01 |
| `07-cleanup.sh` | WireGuard, IPsec 종료 및 정리 | 전체 |

---

## 참고

- [WireGuard Whitepaper](https://www.wireguard.com/papers/wireguard.pdf)
- [StrongSwan IKEv2](https://docs.strongswan.org/docs/5.9/config/quickstart.html)
- `man ipsec.conf`, `man wg`
- Linux XFRM: `net/xfrm/` in kernel source
