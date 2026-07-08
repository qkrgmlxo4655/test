# ArgoCD 배포 테스트용 Makefile
# 사용 순서: make up  ->  make app  ->  make ui

CLUSTER := argocd-test

.PHONY: help
help: ## 사용 가능한 명령 목록
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: cluster
cluster: ## kind 로컬 클러스터 생성
	kind create cluster --config kind-config.yaml

.PHONY: argocd
argocd: ## argocd 네임스페이스에 ArgoCD 설치
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo ">> ArgoCD 서버가 Ready 될 때까지 대기..."
	kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

.PHONY: up
up: cluster argocd ## 클러스터 생성 + ArgoCD 설치를 한 번에

.PHONY: app
app: ## hello 애플리케이션 등록 (ArgoCD가 자동 sync)
	kubectl apply -f argocd/application.yaml
	@echo ">> Application 등록 완료. 상태 확인: kubectl -n argocd get applications"

.PHONY: password
password: ## ArgoCD admin 초기 비밀번호 출력
	@kubectl -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" | base64 -d; echo

.PHONY: ui
ui: ## ArgoCD UI 포트포워딩 (https://localhost:8080), admin 비밀번호도 출력
	@echo ">> admin 비밀번호:" && $(MAKE) -s password
	@echo ">> https://localhost:8080 접속 (Ctrl+C 로 종료)"
	kubectl -n argocd port-forward svc/argocd-server 8080:443

.PHONY: status
status: ## Application / 배포 상태 확인
	kubectl -n argocd get applications
	@echo "---"
	kubectl -n hello get all

.PHONY: test
test: ## 배포된 hello 앱에 실제로 요청을 보내 응답 확인
	kubectl -n hello port-forward svc/hello 8081:80 & \
	PF_PID=$$!; sleep 3; \
	echo ">> curl http://localhost:8081"; \
	curl -s http://localhost:8081 | head -20; \
	kill $$PF_PID

.PHONY: clean
clean: ## kind 클러스터 삭제 (전체 정리)
	kind delete cluster --name $(CLUSTER)
