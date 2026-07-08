# ArgoCD 배포 테스트용 Makefile (k3d + Helm 차트)
# 배포 대상: 저장소 루트의 chart/ 를 values-dev.yaml 로 배포
# 사용 순서: make cluster -> make argocd -> make import-images -> make app -> make ui
#
# 이미 k3d 클러스터 'argocd-test' + ArgoCD가 떠 있다면 import-images -> app 만 하면 됩니다.

# CLUSTER: k3d 이름 / API_PORT: k3s API host 포트 / UI_PORT: ArgoCD UI(8080은 keycloak 점유) / NS: 배포 네임스페이스
CLUSTER  := argocd-test
API_PORT := 6552
UI_PORT  := 8090
APP_PORT := 8082
APP      := test
NS       := test

.PHONY: help
help: ## 사용 가능한 명령 목록
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: cluster
cluster: ## k3d 클러스터 생성 (이미 있으면 건너뜀)
	@if k3d cluster list 2>/dev/null | grep -q "^$(CLUSTER) "; then \
		echo ">> 클러스터 '$(CLUSTER)' 이미 존재 - 건너뜀"; \
	else \
		k3d cluster create $(CLUSTER) --api-port $(API_PORT) --wait; \
	fi
	kubectl config use-context k3d-$(CLUSTER)

.PHONY: argocd
argocd: ## argocd 네임스페이스에 ArgoCD 설치 (idempotent)
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo ">> ArgoCD 서버가 Ready 될 때까지 대기..."
	kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

.PHONY: import-images
import-images: ## 로컬 api-server/worker/frontend 이미지를 dev 태그로 k3d에 로드
	docker tag api-server:latest api-server:base-1.3.0
	docker tag worker:latest     worker:base-1.3.0
	docker tag frontend:latest   frontend:1.3.0-dev
	k3d image import api-server:base-1.3.0 worker:base-1.3.0 frontend:1.3.0-dev -c $(CLUSTER)

.PHONY: app
app: ## test Application 등록 (chart/ + values-dev.yaml 로 배포)
	kubectl apply -f argocd/application.yaml
	@echo ">> 등록 완료. 상태: kubectl -n argocd get applications"

.PHONY: password
password: ## ArgoCD admin 초기 비밀번호 출력
	@kubectl -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath="{.data.password}" | base64 -d; echo

.PHONY: ui
ui: ## ArgoCD UI 포트포워딩 (https://localhost:$(UI_PORT)) + 비밀번호 출력
	@echo ">> admin 비밀번호:" && $(MAKE) -s password
	@echo ">> https://localhost:$(UI_PORT) 접속 (id: admin, Ctrl+C 로 종료)"
	kubectl -n argocd port-forward svc/argocd-server $(UI_PORT):443

.PHONY: status
status: ## Application / 배포 상태 확인
	kubectl -n argocd get applications
	@echo "---"
	kubectl -n $(NS) get deploy,pods,svc

.PHONY: test
test: ## frontend 에 실제로 요청을 보내 응답 확인
	@kubectl -n $(NS) port-forward svc/$(APP)-frontend $(APP_PORT):80 >/dev/null 2>&1 & \
	PF_PID=$$!; sleep 4; \
	echo ">> curl http://localhost:$(APP_PORT)"; \
	curl -s http://localhost:$(APP_PORT) | head -20 || true; \
	kill $$PF_PID 2>/dev/null; wait $$PF_PID 2>/dev/null; true

.PHONY: sync
sync: ## git 최신 상태로 즉시 재동기화 (폴링 안 기다림)
	kubectl -n argocd patch application $(APP) --type merge \
		-p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
	@echo ">> refresh 요청됨. make status 로 확인"

.PHONY: clean-app
clean-app: ## Application만 삭제 (클러스터는 유지)
	kubectl delete -f argocd/application.yaml

.PHONY: clean
clean: ## k3d 클러스터 통째로 삭제
	k3d cluster delete $(CLUSTER)
