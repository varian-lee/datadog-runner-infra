#!/bin/bash

# EKS 배포를 위한 Docker 이미지 빌드 및 ECR 푸시 스크립트

set -e

# 공통 함수 로드
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common-functions.sh"

# 필수 도구 확인
check_required_tools "aws" "docker"

# AWS 환경 확인 (아직 확인되지 않은 경우)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    check_aws_environment
fi

# ECR 권한 확인
check_ecr_permissions

# 설정 변수
ECR_REPOSITORY_PREFIX="datadog-runner"
VERSION=${VERSION:-0.1.0}

log_info "🚀 Docker 이미지 빌드 및 ECR 푸시 시작"
echo "   AWS Account: $AWS_ACCOUNT_ID"
echo "   Region: $AWS_REGION"
echo "   Version: $VERSION"
echo ""

# ECR 로그인
echo "📝 ECR 로그인 중..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# 서비스 목록
SERVICES=("auth-python" "chat-node" "ranking-java" "frontend-react")

for SERVICE in "${SERVICES[@]}"; do
    echo ""
    log_info "🏗️  빌드 중: $SERVICE"
    
    # ECR 레포지토리 생성 (이미 있으면 무시)
    REPO_NAME="$ECR_REPOSITORY_PREFIX/$SERVICE"
    aws ecr describe-repositories --repository-names $REPO_NAME --region $AWS_REGION 2>/dev/null || \
    aws ecr create-repository --repository-name $REPO_NAME --region $AWS_REGION
    
    # Docker 이미지 빌드 (EKS 호환을 위한 linux/amd64 플랫폼)
    if [ "$SERVICE" = "frontend-react" ]; then
        docker buildx build --platform linux/amd64 -t $REPO_NAME:$VERSION ./frontend-react --load
    else
        docker buildx build --platform linux/amd64 -t $REPO_NAME:$VERSION ./services/$SERVICE --load
    fi
    
    # ECR 태그 지정
    ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$VERSION"
    docker tag $REPO_NAME:$VERSION $ECR_URI
    
    # ECR 푸시
    echo "📤 푸시 중: $ECR_URI"
    docker push $ECR_URI
    
    log_success "완료: $SERVICE"
done

echo ""
log_success "🎉 모든 이미지 빌드 및 푸시 완료!"
echo ""
log_info "다음 단계에서 사용할 이미지 URI들:"
for SERVICE in "${SERVICES[@]}"; do
    echo "  $SERVICE: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/$SERVICE:$VERSION"
done
