#!/bin/bash

# 개발용 빠른 배포 스크립트
set -e

SERVICE=$1
if [ -z "$SERVICE" ]; then
    echo "❌ 서비스를 지정해주세요"
    echo "사용법: $0 <service_name>"
    echo "예시: $0 auth-python"
    exit 1
fi

echo "🚀 $SERVICE 빠른 개발 배포 시작..."

# 1. 이미지 빌드 및 푸시
./scripts/dev-build-and-push.sh $SERVICE

# 2. 최신 이미지로 deployment 업데이트
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=ap-northeast-2
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
VERSION="dev-${TIMESTAMP}"

case $SERVICE in
    "auth"|"auth-python")
        echo "📦 auth-python deployment 업데이트 중..."
        kubectl set image deployment/auth-python auth-python=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/auth-python:$VERSION
        kubectl rollout status deployment/auth-python
        ;;
    "chat"|"chat-node")
        echo "📦 chat-node deployment 업데이트 중..."
        kubectl set image deployment/chat-node chat-node=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/chat-node:$VERSION
        kubectl rollout status deployment/chat-node
        ;;
    "ranking"|"ranking-java")
        echo "📦 ranking-java deployment 업데이트 중..."
        kubectl set image deployment/ranking-java ranking-java=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/ranking-java:$VERSION
        kubectl rollout status deployment/ranking-java
        ;;
    "frontend"|"frontend-react")
        echo "📦 frontend deployment 업데이트 중..."
        kubectl set image deployment/frontend frontend=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/frontend-react:$VERSION
        kubectl rollout status deployment/frontend
        ;;
    *)
        echo "❌ 알 수 없는 서비스: $SERVICE"
        exit 1
        ;;
esac

echo "✅ $SERVICE 배포 완료!"
echo "🌐 브라우저에서 테스트: http://k8s-default-runnerin-d1d6c3a6d5-1329256805.ap-northeast-2.elb.amazonaws.com"
