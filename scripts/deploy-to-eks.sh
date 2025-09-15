#!/bin/bash

# EKS에 애플리케이션 배포 스크립트

set -e

# 공통 함수 로드
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common-functions.sh"

# 필수 도구 확인
check_required_tools "kubectl"

# kubectl 환경 확인 (아직 확인되지 않은 경우)
if [ -z "$CURRENT_CONTEXT" ]; then
    check_kubectl_environment
fi

NAMESPACE=${NAMESPACE:-default}

log_info "🚀 EKS에 Datadog Runner 애플리케이션 배포 시작"
echo "   클러스터: $CURRENT_CONTEXT"
echo "   네임스페이스: $NAMESPACE"
echo ""

# 기존 리소스 확인
check_existing_resources "$NAMESPACE"

# 네임스페이스 생성
echo "📂 네임스페이스 확인 중..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 이미지 경로 업데이트
echo "🔄 매니페스트 업데이트 중..."
./scripts/update-manifests.sh

# 인프라 서비스부터 배포 (순서 중요)
echo ""
echo "🗄️  인프라 서비스 배포 중..."
kubectl apply -f ./infra/k8s-updated/postgres.yaml -n $NAMESPACE
kubectl apply -f ./infra/k8s-updated/redis.yaml -n $NAMESPACE
kubectl apply -f ./infra/k8s-updated/rabbitmq.yaml -n $NAMESPACE

echo "⏳ 인프라 서비스 준비 대기 중..."
kubectl wait --for=condition=ready pod -l app=postgres --timeout=300s -n $NAMESPACE
kubectl wait --for=condition=ready pod -l app=redis --timeout=300s -n $NAMESPACE
kubectl wait --for=condition=ready pod -l app=rabbitmq --timeout=300s -n $NAMESPACE

# 애플리케이션 서비스 배포
echo ""
echo "🏗️  애플리케이션 서비스 배포 중..."
kubectl apply -f ./infra/k8s-updated/auth-python.yaml -n $NAMESPACE
kubectl apply -f ./infra/k8s-updated/ranking-java.yaml -n $NAMESPACE
kubectl apply -f ./infra/k8s-updated/chat-node.yaml -n $NAMESPACE

echo "⏳ 애플리케이션 서비스 준비 대기 중..."
kubectl wait --for=condition=ready pod -l app=auth-python --timeout=300s -n $NAMESPACE
kubectl wait --for=condition=ready pod -l app=ranking-java --timeout=300s -n $NAMESPACE
kubectl wait --for=condition=ready pod -l app=chat-node --timeout=300s -n $NAMESPACE

# 프론트엔드 배포
echo ""
echo "🎨 프론트엔드 배포 중..."
kubectl apply -f ./infra/k8s-updated/frontend.yaml -n $NAMESPACE

echo "⏳ 프론트엔드 준비 대기 중..."
kubectl wait --for=condition=ready pod -l app=frontend --timeout=300s -n $NAMESPACE

# Ingress 배포
echo ""
echo "🌐 Ingress 배포 중..."
kubectl apply -f ./infra/k8s-updated/ingress.yaml -n $NAMESPACE

echo ""
log_success "✅ 배포 완료!"
echo ""
log_info "📊 상태 확인:"
kubectl get pods -n $NAMESPACE
echo ""
kubectl get services -n $NAMESPACE
echo ""
kubectl get ingress -n $NAMESPACE

echo ""
log_info "🌍 접속 방법:"
echo "1. Load Balancer 주소 확인:"
echo "   kubectl get ingress runner-ingress -n $NAMESPACE"
echo ""
echo "2. /etc/hosts에 추가:"
echo "   <LOAD_BALANCER_IP> runner.local"
echo ""
echo "3. 브라우저에서 접속:"
echo "   http://runner.local"
