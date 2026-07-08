# ArgoCD 배포 테스트 환경 (k3d + Helm)

로컬 **k3d** 클러스터에서 **ArgoCD**가 이 저장소의 **Helm 차트(`chart/`)** 를
**`values-dev.yaml`** 로 배포하는 GitOps 흐름을 테스트하는 환경입니다.

---

## 1. 개념

```
  [ Git ]                         [ ArgoCD ]                  [ k3d ]
  chart/  (Helm 차트)      ──→   차트를 values-dev.yaml    ──→   api / worker / frontend
  chart/values-dev.yaml          로 렌더링 후 동기화               Deployment + Service
```

- **차트(`chart/`)** 가 `api` / `worker` / `frontend` 3개 컴포넌트의 매니페스트 틀을 정의.
- **`values.yaml`** 은 기본값(이미지 repository, 포트, 리소스 등).
- **`values-dev.yaml`** 은 dev 환경 오버라이드 — 지금은 **이미지 태그만** 덮어씀.
- ArgoCD가 `chart/` 를 Helm 으로 렌더링하고 `values-dev.yaml` 을 얹어 클러스터에 배포.

---

## 2. 구조

```
저장소 루트/
├── chart/                       # ← 배포 대상 Helm 차트
│   ├── Chart.yaml
│   ├── values.yaml              # 기본값 (repository=api-server/worker/frontend, 포트, 리소스)
│   ├── values-dev.yaml          # dev 오버라이드 (image.tag 만)
│   └── templates/
│       ├── _helpers.tpl
│       └── workloads.yaml       # 3개 컴포넌트를 Deployment(+Service)로 렌더링
└── argocd-test/
    ├── Makefile                 # 원커맨드 헬퍼
    ├── README.md                # (이 파일)
    └── argocd/
        └── application.yaml      # ArgoCD Application (path: chart, values: values-dev.yaml)
```

### 값 병합 규칙
ArgoCD/Helm 은 **`chart/values.yaml`(기본값) → `values-dev.yaml`(오버라이드)** 순으로 병합합니다.
그래서 `values-dev.yaml` 에 `tag` 만 있어도 `repository` 등은 기본값에서 채워집니다.

```yaml
# values.yaml
api: { image: { repository: api-server, tag: latest }, ... }
# values-dev.yaml
api: { image: { tag: base-1.3.0 } }
# => 최종: api-server:base-1.3.0
```

---

## 3. 사전 준비물

| 도구 | 상태 | 설치 |
|------|------|------|
| docker | ✅ | - |
| kubectl | ✅ | - |
| helm | ✅ | - |
| **k3d** | 필요 | `brew install k3d` |

로컬에 `api-server:latest`, `worker:latest`, `frontend:latest` 이미지가 있어야
`make import-images` 로 k3d 에 넣을 수 있습니다.

---

## 4. 실행

`argocd-test/` 안에서:

```bash
make cluster        # k3d 클러스터 생성 (이미 있으면 skip)
make argocd         # ArgoCD 설치 (idempotent)
make import-images  # 로컬 이미지를 dev 태그로 k3d 에 로드
make app            # test Application 등록 -> 자동 배포
make status         # 상태 확인
make test           # frontend 에 curl
```

> **이미지 이야기**: `values-dev.yaml` 의 태그(`base-1.3.0`, `1.3.0-dev`)는 사설 이미지라
> 공개 레지스트리에 없습니다. `make import-images` 가 로컬 이미지를 그 태그로 재태깅해
> k3d 에 직접 넣어주므로 pull 없이 배포됩니다. (`imagePullPolicy: IfNotPresent`)
> api/worker 는 백엔드(DB·큐 등)가 없으면 CrashLoop 일 수 있는데, 이는 앱 특성이며
> **ArgoCD 의 sync(매니페스트 렌더링·배포) 자체는 정상 동작**합니다.

### UI

```bash
make ui   # https://localhost:8090 (id: admin, 비밀번호 자동 출력)
```

`test` 앱을 클릭하면 api/worker/frontend 리소스 트리와 상태가 보입니다.

---

## 5. GitOps 흐름 테스트

```bash
# values-dev.yaml 에서 frontend 태그를 바꾸거나 replicaCount 를 조정 후
git add chart/ && git commit -m "bump frontend" && git push
make sync            # 즉시 재동기화 (안 하면 기본 폴링 3분)
make status
```

`selfHeal` 확인:
```bash
kubectl -n test scale deploy/test-frontend --replicas=3
# ArgoCD 가 git 기준(1)으로 되돌립니다.
```

---

## 6. 명령어 요약 (`make help`)

| 명령 | 설명 |
|------|------|
| `make cluster`       | k3d 클러스터 생성 (있으면 skip) |
| `make argocd`        | ArgoCD 설치 |
| `make import-images` | 로컬 이미지를 dev 태그로 k3d 에 로드 |
| `make app`           | test Application 등록 |
| `make status`        | 상태 확인 |
| `make test`          | frontend 에 curl |
| `make ui`            | UI 포트포워딩 + 비밀번호 |
| `make sync`          | 즉시 재동기화 |
| `make clean-app`     | Application 삭제 (클러스터 유지) |
| `make clean`         | 클러스터 통째로 삭제 |

---

## 7. 주의

- **Application 은 git(원격 main)을 봅니다.** `chart/` 를 로컬에서 고쳐도 **push 전에는
  반영되지 않습니다.** `git push` 후 `make sync`(또는 3분 대기).
- 다른 저장소·브랜치·values 파일로 바꾸려면 `argocd/application.yaml` 의
  `repoURL` / `targetRevision` / `path` / `helm.valueFiles` 를 수정하세요.
- UI 포트가 8090 인 이유: 이 머신은 8080 을 `mrx-keycloak` 이 점유 중이라 충돌 회피.
