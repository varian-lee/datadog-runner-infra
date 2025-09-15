#!/bin/bash

# EKS에 Datadog Agent 설치 스크립트

set -e

# 공통 함수 로드
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common-functions.sh"

# 필수 도구 확인
check_required_tools "kubectl" "helm"

# kubectl 환경 확인 (아직 확인되지 않은 경우)
if [ -z "$CURRENT_CONTEXT" ]; then
    check_kubectl_environment
fi

# Datadog 설정
DD_API_KEY=${DD_API_KEY}
DD_SITE=${DD_SITE:-datadoghq.com}

log_info "🐕 Datadog Agent 설치 시작"
echo "   클러스터: $CURRENT_CONTEXT"
echo "   Datadog Site: $DD_SITE"
echo ""

if [ -z "$DD_API_KEY" ]; then
    log_error "DD_API_KEY 환경변수가 설정되지 않았습니다."
    echo "다음 명령어로 설정하세요:"
    echo "  export DD_API_KEY=your-api-key-here"
    exit 1
fi

# Datadog Helm 레포지토리 추가
echo "📦 Helm 레포지토리 추가 중..."
helm repo add datadog https://helm.datadoghq.com
helm repo update

# Datadog Secret 생성
echo "🔐 Datadog Secret 생성 중..."
kubectl create secret generic datadog-secret \
    --from-literal api-key=$DD_API_KEY \
    --namespace=default \
    --dry-run=client -o yaml | kubectl apply -f -

# Datadog Agent 설치
echo "🚀 Datadog Agent 설치 중..."
helm upgrade --install datadog-agent datadog/datadog \
    --namespace=default \
    --values=./infra/datadog/helm-values.yaml \
    --set datadog.site=$DD_SITE

echo "⏳ Datadog Agent 시작 대기 중..."
kubectl wait --for=condition=ready pod -l app=datadog-agent --timeout=300s -n default

echo ""
log_success "✅ Datadog Agent 설치 완료!"
echo ""
log_info "📊 상태 확인:"
kubectl get pods -l app=datadog-agent -n default

echo ""
log_info "🔍 로그 확인:"
echo "  kubectl logs -l app=datadog-agent -n default"
echo ""
log_info "🌐 Datadog 대시보드에서 확인:"
echo "  https://app.$DD_SITE/infrastructure/map"
