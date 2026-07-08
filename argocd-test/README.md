# ArgoCD 배포 테스트 환경

로컬에서 kind 클러스터에 ArgoCD를 설치하고, 이 저장소의 매니페스트를
GitOps 방식으로 배포/동기화하는 걸 간단히 테스트하는 환경입니다.

## 구성

```
argocd-test/
├── Makefile                 # 원커맨드 실행 헬퍼
├── kind-config.yaml         # 로컬 클러스터 설정
├── argocd/
│   └── application.yaml      # ArgoCD Application (배포 정의)
└── apps/
    └── hello/               # 실제 배포되는 샘플 앱 (nginx hello)
        ├── deployment.yaml
        └── service.yaml
```

- **ArgoCD Application** `argocd/application.yaml` 은 이 저장소의
  `argocd-test/apps/hello` 경로를 바라봅니다.
- `automated` sync + `selfHeal` 이 켜져 있어, git에 push하면 자동으로 클러스터에 반영됩니다.

## 사전 준비물

| 도구 | 설치 여부 | 설치 |
|------|-----------|------|
| docker | ✅ | - |
| kubectl | ✅ | - |
| helm | ✅ | - |
| **kind** | ❌ | `brew install kind` |

> ArgoCD CLI는 필수가 아닙니다. UI + kubectl 로 충분히 테스트됩니다.
> (원하면 `brew install argocd`)

## 실행

`argocd-test/` 디렉토리 안에서:

```bash
# 1. 클러스터 생성 + ArgoCD 설치 (몇 분 소요)
make up

# 2. hello 애플리케이션을 ArgoCD에 등록 -> 자동으로 배포됨
make app

# 3. 배포 상태 확인
make status

# 4. 실제 앱에 요청 보내 응답 확인
make test
```

### ArgoCD UI 로 확인

```bash
make ui
```

- 브라우저에서 https://localhost:8080 (자체 서명 인증서 경고는 무시)
- 사용자: `admin`
- 비밀번호: 출력된 값 (또는 `make password`)

UI에서 `hello` 앱이 **Synced / Healthy** 상태로 뜨면 정상입니다.

## GitOps 흐름 테스트해보기

ArgoCD의 핵심인 "git = 진실의 원천" 을 직접 확인하는 방법:

1. `apps/hello/deployment.yaml` 의 `replicas: 2` → `3` 으로 변경
2. `git add . && git commit -m "scale hello to 3" && git push`
3. 잠시 후 (기본 폴링 3분, 또는 UI/CLI에서 `Refresh`) 파드가 3개로 늘어남
   ```bash
   kubectl -n hello get pods
   ```

`selfHeal` 테스트:

```bash
# 클러스터에서 직접 스케일을 바꿔봐도
kubectl -n hello scale deploy/hello --replicas=1
# ArgoCD가 git 기준(2 또는 3)으로 되돌려 놓습니다.
```

## 정리

```bash
make clean   # kind 클러스터 통째로 삭제
```

## 참고

- Application이 바라보는 저장소는 `argocd/application.yaml` 의 `repoURL` 입니다.
  현재 `https://github.com/qkrgmlxo4655/test.git` / `main` 브랜치로 설정되어 있으니,
  **변경사항은 반드시 git push** 해야 ArgoCD가 볼 수 있습니다.
- 다른 저장소/브랜치로 테스트하려면 `repoURL`, `targetRevision`, `path` 를 수정하세요.
