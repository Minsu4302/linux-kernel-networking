# CLAUDE.md

이 문서는 Claude Code가 `linux-kernel-networking` 레포에서 작업할 때 따르는 규칙입니다. 사람 독자를 위한 프로젝트 소개는 [`README.md`](./README.md)를 참고하세요.

## 프로젝트 컨텍스트

- 목적: 백엔드 개발자가 K8s/클라우드 네트워킹의 내부 동작 원리를 Linux 커널 기능으로 직접 구현하며 학습. 결과물은 면접/포트폴리오용 레포지토리.
- 환경: GCP Compute Engine VM (Ubuntu), 멀티 VM 실습 다수 포함.
- 산출물 단위: 주제 1개 = 폴더 1개 = 브랜치 1개 = PR 1개.
- 주제 진행 순서는 README.md의 표를 따름 (난이도/의존성 기준으로 설계된 순서이므로 임의로 순서를 바꾸지 않음).

## 디렉토리 컨벤션

각 주제 폴더(`0N-주제명/`)는 반드시 아래 구조를 따릅니다.

```
0N-주제명/
├── README.md       # 개념 설명: 핵심 기술, 아키텍처 다이어그램(mermaid), 왜 이 주제를 다루는지
├── PROGRESS.md      # 진행 로그: 날짜별 TIL, 트러블슈팅(증상→원인→해결), 학습 키워드 목록
├── scripts/          # 실습에 쓴 bash/python 스크립트. 실행 가능한 상태로 유지
└── diagrams/         # 구조도, 패킷 캡처 스크린샷 등 시각 자료
```

새 주제를 시작할 때는 기존 폴더의 `README.md` / `PROGRESS.md` 템플릿 구조를 그대로 복사해서 일관성을 유지합니다.

## 브랜치 전략

```
main
 └── feature/0N-주제명   (예: feature/01-k8s-service-from-scratch)
```

- 브랜치명은 폴더명과 동일하게 `feature/` 접두사를 붙입니다.
- 한 브랜치에는 한 주제만 다룹니다. 여러 주제를 섞지 않습니다.
- `main`은 항상 머지된 결과만 존재해야 하며, `main`에서 직접 작업하지 않습니다.

## 커밋 컨벤션

[Conventional Commits](https://www.conventionalcommits.org/) 형식을 사용합니다.

```
<type>(<scope>): <설명>
```

- `type`: `feat`(새 실습/스크립트 추가), `docs`(README/PROGRESS 갱신), `fix`(스크립트 버그 수정), `chore`(인프라/환경 설정)
- `scope`: 주제 폴더명 약어

| 주제 | scope |
|------|-------|
| 01. K8s Service | `k8s-svc` |
| 02. L4/L7 로드밸런서 비교 | `lb-compare` |
| 03. DNS & CoreDNS | `dns` |
| 04. 터널링 & 오버레이 | `vxlan` |
| 05. MTU 트러블슈팅 | `mtu` |
| 06. Conntrack & NAT | `conntrack` |
| 07. eBPF | `ebpf` |
| 08. sysctl 튜닝 | `sysctl` |
| 09. Ad-hoc & Mesh | `mesh` |
| 10. VPN 비교 | `vpn` |
| 11. XDP DDoS 방어 | `xdp-ddos` |
| 12. Network Policy 벤치마크 | `netpol` |
| 13. BGP & ECMP | `bgp` |
| 14. HA Failover | `ha` |
| 15. Cilium CNI | `cilium` |

- 설명은 한글로, "무엇을" 보다 "왜/어떤 변화" 중심으로 작성

예시:
```
feat(k8s-svc): iptables DNAT로 ClusterIP 재현
docs(k8s-svc): IPVS 성능 비교 결과 PROGRESS.md에 기록
fix(vxlan): VNI 불일치로 터널 안 붙던 문제 수정
chore(infra): 실습용 VM 3대 생성 스크립트 추가
```

- 커밋은 의미 단위로 나눕니다. "스크립트 작성", "실행 결과 기록", "문서 정리"를 한 커밋에 섞지 않습니다.
- 매 커밋마다 실제로 명령을 실행하고 결과를 확인한 뒤 커밋합니다. 검증 안 된 스크립트를 커밋하지 않습니다.

## PR 규칙

- 제목: 커밋 컨벤션과 동일한 형식 `feat(scope): 요약`
- 본문은 `.github/pull_request_template.md` 템플릿을 따릅니다. 최소한 다음을 포함:
  - 무엇을 구현했는지
  - 왜 이렇게 구현했는지 (대안과 비교, 있다면)
  - 실행 결과/증거 (커맨드 출력, 캡처 등은 텍스트로 요약하거나 `diagrams/`에 저장 후 링크)
  - 트러블슈팅 중 막혔던 부분과 해결 과정 (`PROGRESS.md` 링크)
- PR을 올리기 전, 해당 주제의 `README.md`와 `PROGRESS.md`가 최신 상태인지 확인합니다.

## 셀프 코드 리뷰 기준

PR을 머지하기 전 다음 항목을 점검합니다.

1. **재현 가능성**: `scripts/` 안의 명령어를 그대로 따라 했을 때 동일한 결과가 나오는가? 환경 의존적인 하드코딩(특정 IP, 인터페이스명 등)이 있다면 주석으로 명시했는가?
2. **보안 노출**: 스크립트나 커밋 내용에 GCP 프로젝트 ID, 외부 IP, SSH 키, 인증 토큰 등 민감 정보가 평문으로 들어가지 않았는가?
3. **문서 일관성**: README.md(개념)과 PROGRESS.md(실제 진행 로그)의 내용이 서로 모순되지 않는가?
4. **정리(cleanup)**: 실습에만 쓰고 더 이상 필요 없는 VM/리소스가 있다면 `infra/INSTANCES.md`에 정리 여부를 기록했는가?

리뷰에서 발견된 문제는 같은 PR 내에서 추가 커밋으로 수정 후 머지합니다.

## 머지 정책

- 셀프 리뷰 체크리스트를 모두 통과하면 `main`으로 머지(squash 권장: 커밋 히스토리보다 주제별 결과물 단위가 더 중요).
- 머지 후 루트 `README.md`의 진행 현황 표 상태를 ✅ 완료로 갱신합니다.

## GCP 인프라 작업 시 주의사항

- 새 VM을 생성/삭제할 때는 `infra/INSTANCES.md`에 반드시 기록 (생성일, 스펙, 리전, 용도, 삭제 여부).
- 무료 체험판 크레딧 사용 중이므로, 실습이 끝난 VM은 가능한 빨리 중지(stop) 또는 삭제하여 불필요한 비용 발생을 방지합니다.
- 멀티 VM이 필요한 실습(04, 05, 09, 10)은 시작 전 몇 대가 필요한지 README.md에 명시하고, 끝나면 즉시 정리합니다.
