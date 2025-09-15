#!/bin/bash

# 개발용 빌드 스크립트 - 타임스탬프 기반 이미지 태깅
set -e

source "$(dirname "$0")/common-functions.sh"

# 환경 확인
check_required_tools
check_aws_environment

AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}
AWS_REGION=${AWS_REGION:-ap-northeast-2}

# 개발용: 타임스탬프 기반 태깅
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
VERSION="dev-${TIMESTAMP}"

log_info "🚀 개발용 이미지 빌드 시작 (버전: $VERSION)"

# 특정 서비스만 빌드하는 옵션
SERVICE=$1

build_service() {
    local service=$1
    local service_dir=$2
    
    log_info "📦 $service 이미지 빌드 중..."
    
    # 개발용: 변경된 파일만 감지해서 빌드
    docker buildx build \
        --platform linux/amd64 \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        -t datadog-runner/$service:$VERSION \
        $service_dir --load
    
    # ECR에 태깅 및 푸시
    docker tag datadog-runner/$service:$VERSION \
        $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/$service:$VERSION
    
    log_info "📤 $service 이미지 푸시 중..."
    docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/$service:$VERSION
    
    log_success "✅ $service 완료: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/$service:$VERSION"
}

# 특정 서비스 빌드 또는 전체 빌드
case $SERVICE in
    "auth"|"auth-python")
        build_service "auth-python" "./services/auth-python"
        ;;
    "chat"|"chat-node")
        build_service "chat-node" "./services/chat-node"
        ;;
    "ranking"|"ranking-java")
        build_service "ranking-java" "./services/ranking-java"
        ;;
    "frontend"|"frontend-react")
        build_service "frontend-react" "./frontend-react"
        ;;
    "")
        # 전체 빌드
        build_service "auth-python" "./services/auth-python"
        build_service "chat-node" "./services/chat-node"
        build_service "ranking-java" "./services/ranking-java"
        build_service "frontend-react" "./frontend-react"
        ;;
    *)
        log_error "❌ 알 수 없는 서비스: $SERVICE"
        log_info "사용법: $0 [auth|chat|ranking|frontend]"
        exit 1
        ;;
esac

log_success "🎉 개발용 빌드 완료!"
log_info "📋 다음 명령어로 특정 서비스 배포:"
log_info "   kubectl set image deployment/auth-python auth-python=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/auth-python:$VERSION"
log_info "   kubectl set image deployment/chat-node chat-node=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/chat-node:$VERSION"
log_info "   kubectl set image deployment/ranking-java ranking-java=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/ranking-java:$VERSION"
log_info "   kubectl set image deployment/frontend frontend=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/frontend-react:$VERSION"
