#!/bin/bash

# EKS 전체 배포 마스터 스크립트

set -e

# 공통 함수 로드
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common-functions.sh"

echo "🎯 Datadog Runner EKS 전체 배포 시작"
echo "========================================"

# 필수 도구 확인
check_required_tools "aws" "eksctl" "kubectl" "helm" "docker"

# AWS 환경 확인
check_aws_environment

# 비용 경고
show_cost_warning "150"

# 클러스터 생성 여부 확인
CLUSTER_NAME=${CLUSTER_NAME:-datadog-runner-cluster}
echo ""
read -p "🤔 EKS 클러스터를 생성하시겠습니까? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # 클러스터 충돌 확인
    if check_cluster_conflict "$CLUSTER_NAME" "$AWS_REGION"; then
        echo ""
        log_info "🏗️  1단계: EKS 클러스터 생성"
        ./scripts/create-eks-cluster.sh
        
        echo ""
        log_info "⏳ 클러스터 안정화를 위해 2분 대기..."
        sleep 120
    fi
else
    log_info "⏭️  클러스터 생성을 건너뛰었습니다."
fi

# kubectl 환경 확인 (기존 또는 새로 생성된 클러스터)
check_kubectl_environment

echo ""
echo "🐳 2단계: Docker 이미지 빌드 및 ECR 푸시"
./scripts/build-and-push.sh

echo ""
echo "🚀 3단계: 애플리케이션 배포"
./scripts/deploy-to-eks.sh

echo ""
read -p "🐕 Datadog Agent를 설치하시겠습니까? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -z "$DD_API_KEY" ]; then
        echo ""
        read -p "🔑 Datadog API Key를 입력하세요: " DD_API_KEY
        export DD_API_KEY
    fi
    
    echo ""
    echo "🐕 4단계: Datadog Agent 설치"
    ./scripts/install-datadog.sh
else
    echo "⏭️  Datadog 설치를 건너뛰었습니다."
fi

echo ""
echo "🎉 배포 완료!"
echo "=============="
echo ""
echo "📊 클러스터 상태:"
kubectl get nodes
echo ""
kubectl get pods --all-namespaces
echo ""
echo "🌐 Load Balancer 주소 확인:"
kubectl get ingress
echo ""
echo "📝 다음 단계:"
echo "1. Load Balancer 주소를 /etc/hosts에 추가"
echo "2. 브라우저에서 http://runner.local 접속"
echo "3. Datadog 대시보드에서 모니터링 확인"
