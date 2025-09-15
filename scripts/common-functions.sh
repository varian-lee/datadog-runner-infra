#!/bin/bash

# 공통 함수들 - 다른 스크립트에서 source로 로드하여 사용

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수들
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# AWS 환경 확인 함수
check_aws_environment() {
    log_info "AWS 환경 확인 중..."
    
    # AWS CLI 설치 확인
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI가 설치되지 않았습니다."
        exit 1
    fi
    
    # AWS 인증 확인
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS 인증이 설정되지 않았습니다."
        echo "다음 명령어로 설정하세요: aws configure"
        exit 1
    fi
    
    # 현재 AWS 환경 정보 가져오기
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    AWS_REGION=$(aws configure get region)
    
    if [ -z "$AWS_REGION" ]; then
        AWS_REGION="ap-northeast-2"
        log_warning "AWS 리전이 설정되지 않아 기본값 사용: $AWS_REGION"
    fi
    
    echo ""
    echo "📋 현재 AWS 환경:"
    echo "   계정 ID: $AWS_ACCOUNT_ID"
    echo "   사용자: $AWS_USER_ARN"
    echo "   리전: $AWS_REGION"
    echo ""
    
    # 사용자 확인
    read -p "🤔 위 AWS 환경이 올바른가요? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "AWS 환경을 다시 확인해주세요."
        echo "계정 변경: aws configure --profile <profile-name>"
        echo "리전 변경: aws configure set region <region-name>"
        exit 1
    fi
    
    log_success "AWS 환경 확인 완료"
    export AWS_ACCOUNT_ID
    export AWS_REGION
}

# kubectl 환경 확인 함수
check_kubectl_environment() {
    log_info "Kubernetes 환경 확인 중..."
    
    # kubectl 설치 확인
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl이 설치되지 않았습니다."
        exit 1
    fi
    
    # 클러스터 연결 확인
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Kubernetes 클러스터에 연결되지 않았습니다."
        echo "다음 명령어로 연결하세요:"
        echo "  aws eks update-kubeconfig --region $AWS_REGION --name <cluster-name>"
        exit 1
    fi
    
    # 현재 컨텍스트 정보
    CURRENT_CONTEXT=$(kubectl config current-context)
    CURRENT_CLUSTER=$(kubectl config view --minify --output 'jsonpath={..cluster.server}')
    CURRENT_NAMESPACE=$(kubectl config view --minify --output 'jsonpath={..namespace}')
    
    if [ -z "$CURRENT_NAMESPACE" ]; then
        CURRENT_NAMESPACE="default"
    fi
    
    echo ""
    echo "🎯 현재 Kubernetes 환경:"
    echo "   컨텍스트: $CURRENT_CONTEXT"
    echo "   클러스터: $CURRENT_CLUSTER"
    echo "   네임스페이스: $CURRENT_NAMESPACE"
    echo ""
    
    # 노드 정보 표시
    echo "📊 클러스터 노드:"
    kubectl get nodes --no-headers | head -5
    if [ $(kubectl get nodes --no-headers | wc -l) -gt 5 ]; then
        echo "   ... (총 $(kubectl get nodes --no-headers | wc -l)개 노드)"
    fi
    echo ""
    
    # 사용자 확인
    read -p "🤔 위 Kubernetes 환경이 올바른가요? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "Kubernetes 환경을 다시 확인해주세요."
        echo "컨텍스트 확인: kubectl config get-contexts"
        echo "컨텍스트 변경: kubectl config use-context <context-name>"
        exit 1
    fi
    
    log_success "Kubernetes 환경 확인 완료"
    export CURRENT_CONTEXT
    export CURRENT_NAMESPACE
}

# 비용 경고 함수
show_cost_warning() {
    local estimated_cost=$1
    echo ""
    log_warning "💰 예상 비용 안내"
    echo "   예상 월 비용: ~\$${estimated_cost} USD"
    echo "   주요 비용: EKS 클러스터(\$0.10/시간) + EC2 인스턴스 + Load Balancer"
    echo "   💡 테스트 후 cleanup-eks.sh로 정리하여 비용을 절약하세요!"
    echo ""
    
    read -p "🤔 비용에 동의하고 계속하시겠습니까? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "사용자가 취소했습니다."
        exit 0
    fi
}

# 클러스터 충돌 확인 함수
check_cluster_conflict() {
    local cluster_name=$1
    local region=${2:-$AWS_REGION}
    
    log_info "기존 클러스터 확인 중..."
    
    if aws eks describe-cluster --name "$cluster_name" --region "$region" &> /dev/null; then
        log_warning "동일한 이름의 클러스터가 이미 존재합니다: $cluster_name"
        echo ""
        read -p "🤔 기존 클러스터를 사용하시겠습니까? (y) 또는 새로 생성하시겠습니까? (n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "기존 클러스터를 사용합니다."
            # kubeconfig 업데이트
            aws eks update-kubeconfig --region "$region" --name "$cluster_name"
            return 1  # 기존 클러스터 사용
        else
            log_error "다른 클러스터 이름을 사용하거나 기존 클러스터를 삭제하세요."
            echo "삭제 명령어: eksctl delete cluster --name $cluster_name --region $region"
            exit 1
        fi
    fi
    
    return 0  # 새 클러스터 생성 가능
}

# ECR 권한 확인 함수
check_ecr_permissions() {
    log_info "ECR 권한 확인 중..."
    
    # ECR 로그인 테스트
    if ! aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com" &> /dev/null; then
        log_error "ECR 로그인에 실패했습니다."
        echo "IAM 권한을 확인하세요: AmazonEC2ContainerRegistryFullAccess"
        exit 1
    fi
    
    log_success "ECR 권한 확인 완료"
}

# 리소스 존재 확인 함수
check_existing_resources() {
    local namespace=${1:-default}
    
    log_info "기존 리소스 확인 중..."
    
    # 기존 배포 확인
    if kubectl get deployment --no-headers -n "$namespace" 2>/dev/null | grep -q .; then
        log_warning "네임스페이스 '$namespace'에 기존 배포가 존재합니다:"
        kubectl get deployment -n "$namespace"
        echo ""
        read -p "🤔 기존 리소스를 덮어쓰시겠습니까? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "사용자가 취소했습니다."
            exit 0
        fi
    fi
}

# 필수 도구 확인 함수
check_required_tools() {
    local tools=("$@")
    local missing_tools=()
    
    log_info "필수 도구 확인 중..."
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "다음 도구들이 설치되지 않았습니다:"
        for tool in "${missing_tools[@]}"; do
            echo "  - $tool"
        done
        echo ""
        echo "설치 명령어:"
        echo "  brew install ${missing_tools[*]}"
        exit 1
    fi
    
    log_success "모든 필수 도구가 설치되어 있습니다."
}
