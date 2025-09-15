#!/bin/bash

# Kubernetes 매니페스트에서 이미지 경로 업데이트 스크립트

set -e

# 공통 함수 로드
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common-functions.sh"

# AWS 환경 확인 (아직 확인되지 않은 경우)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    check_aws_environment
fi

VERSION=${VERSION:-0.1.0}
ECR_REPOSITORY_PREFIX="datadog-runner"

log_info "🔄 Kubernetes 매니페스트 이미지 경로 업데이트 중..."
echo "   AWS Account: $AWS_ACCOUNT_ID"
echo "   Region: $AWS_REGION"
echo "   Version: $VERSION"
echo ""

# 임시 디렉토리 생성
TEMP_DIR="./infra/k8s-updated"
mkdir -p $TEMP_DIR

# 원본 매니페스트 복사 및 이미지 경로 업데이트
for file in ./infra/k8s/*.yaml; do
    filename=$(basename "$file")
    echo "📝 업데이트 중: $filename"
    
    # 이미지 경로 치환
    sed "s|yourrepo/auth-python:0.1.0|$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/auth-python:$VERSION|g" "$file" | \
    sed "s|yourrepo/chat-node:0.1.0|$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/chat-node:$VERSION|g" | \
    sed "s|yourrepo/ranking-java:0.1.0|$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/ranking-java:$VERSION|g" | \
    sed "s|yourrepo/frontend-react:0.1.0|$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY_PREFIX/frontend-react:$VERSION|g" > "$TEMP_DIR/$filename"
done

log_success "✅ 업데이트된 매니페스트가 $TEMP_DIR 에 생성되었습니다."
echo ""
log_info "다음 명령어로 배포하세요:"
echo "  kubectl apply -f $TEMP_DIR/"
