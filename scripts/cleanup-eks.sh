#!/bin/bash

# EKS 클러스터 및 관련 리소스 정리 스크립트

set -e

# 공통 함수 로드
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common-functions.sh"

# 필수 도구 확인
check_required_tools "eksctl" "kubectl" "aws"

# AWS 환경 확인
check_aws_environment

CLUSTER_NAME=${CLUSTER_NAME:-datadog-runner-cluster}

log_warning "🧹 EKS 클러스터 정리 시작"
echo "   클러스터명: $CLUSTER_NAME"
echo "   지역: $AWS_REGION"
echo "   계정: $AWS_ACCOUNT_ID"

# 확인 메시지
echo ""
echo "⚠️  주의: 다음 리소스들이 삭제됩니다:"
echo "  - EKS 클러스터: $CLUSTER_NAME"
echo "  - 모든 워커 노드"
echo "  - Load Balancer"
echo "  - VPC 및 서브넷 (클러스터 전용인 경우)"
echo ""
read -p "🤔 정말로 삭제하시겠습니까? (yes/no): " -r
if [[ ! $REPLY =~ ^(yes|YES)$ ]]; then
    echo "❌ 취소되었습니다."
    exit 0
fi

# Datadog Agent 제거
echo ""
echo "🐕 Datadog Agent 제거 중..."
helm uninstall datadog-agent --namespace=default || echo "⚠️  Datadog Agent가 설치되지 않았거나 이미 제거됨"

# AWS Load Balancer Controller 제거
echo ""
echo "🔧 AWS Load Balancer Controller 제거 중..."
helm uninstall aws-load-balancer-controller --namespace=kube-system || echo "⚠️  Load Balancer Controller가 설치되지 않았거나 이미 제거됨"

# 애플리케이션 리소스 제거
echo ""
echo "🗑️  애플리케이션 리소스 제거 중..."
kubectl delete ingress --all --all-namespaces || true
kubectl delete service --all --all-namespaces --field-selector metadata.name!=kubernetes || true
kubectl delete deployment --all --all-namespaces || true
kubectl delete pod --all --all-namespaces --force --grace-period=0 || true

# LoadBalancer 타입 서비스 완전 삭제 대기
echo ""
echo "⏳ Load Balancer 삭제 대기 중... (최대 5분)"
timeout 300 bash -c '
while kubectl get svc --all-namespaces | grep -q LoadBalancer; do
    echo "아직 LoadBalancer 서비스가 남아있습니다..."
    sleep 10
done
' || echo "⚠️  시간 초과: 수동으로 AWS 콘솔에서 Load Balancer를 확인하세요."

# EKS 클러스터 삭제
echo ""
echo "🏗️  EKS 클러스터 삭제 중... (약 10-15분 소요)"
eksctl delete cluster --name=$CLUSTER_NAME --region=$AWS_REGION

echo ""
log_success "✅ 클러스터 정리 완료!"
echo ""
log_info "📊 확인사항:"
echo "1. AWS 콘솔에서 다음 리소스들이 삭제되었는지 확인:"
echo "   - EC2 인스턴스"
echo "   - Load Balancer"
echo "   - VPC (클러스터 전용인 경우)"
echo "   - ECR 레포지토리 (필요시 수동 삭제)"
echo ""
echo "2. 예상 비용 절약: 노드 인스턴스 요금 중단"
