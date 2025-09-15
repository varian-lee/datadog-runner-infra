#!/bin/bash

# 개발용 단일 서비스 빌드/배포 스크립트 - 동적 태깅으로 캐시 문제 해결
# 기존 문제: ImagePullPolicy: Always 사용 시에도 ECR 같은 태그로 인한 캐시 문제 발생
# 해결책: 매 배포마다 고유한 태그 생성으로 확실한 이미지 업데이트 보장
set -e

SERVICE=$1
if [ -z "$SERVICE" ]; then
    echo "❌ 서비스를 지정해주세요"
    echo "사용법: $0 <service_name>"
    echo "예시: $0 auth-python"
    exit 1
fi

# AWS ECR 설정
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=ap-northeast-2

# ECR 자동 로그인 (간단하고 확실한 방법)
echo "🔐 ECR 로그인 중..."
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# 매번 ECR 로그인 시도 (이미 로그인되어 있으면 빠르게 완료됨)
if aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}; then
    echo "✅ ECR 로그인 성공!"
else
    echo "❌ ECR 로그인 실패!"
    echo "💡 AWS CLI 설정을 확인하고 권한을 확인하세요."
    echo "   필요한 IAM 권한: ecr:GetAuthorizationToken, ecr:BatchCheckLayerAvailability, ecr:GetDownloadUrlForLayer, ecr:BatchGetImage"
    exit 1
fi

# Kubernetes 클러스터 컨텍스트 확인 - 실수 방지
echo "🔍 Kubernetes 클러스터 컨텍스트 확인 중..."
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
EXPECTED_CONTEXT="datadog-runner-cluster"

echo "📋 현재 활성 컨텍스트: $CURRENT_CONTEXT"

# 클러스터 컨텍스트 검증
if [[ "$CURRENT_CONTEXT" == "none" ]]; then
    echo "❌ Kubernetes 컨텍스트가 설정되지 않았습니다."
    echo "💡 다음 명령으로 올바른 컨텍스트를 설정하세요:"
    echo "   kubectl config use-context kihyun_tam@datadog-runner-cluster.ap-northeast-2.eksctl.io"
    exit 1
elif [[ "$CURRENT_CONTEXT" == "docker-desktop" ]]; then
    echo "⚠️  현재 docker-desktop(로컬) 컨텍스트에 연결되어 있습니다!"
    echo "🚨 실제 EKS 클러스터에 배포하려면 컨텍스트를 변경해야 합니다."
    echo ""
    echo "올바른 컨텍스트로 변경하시겠습니까? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "🔄 EKS 클러스터로 컨텍스트 변경 중..."
        kubectl config use-context kihyun_tam@datadog-runner-cluster.ap-northeast-2.eksctl.io
        echo "✅ 컨텍스트 변경 완료!"
    else
        echo "❌ 배포를 취소합니다."
        exit 1
    fi
elif [[ "$CURRENT_CONTEXT" != *"$EXPECTED_CONTEXT"* ]]; then
    echo "⚠️  예상하지 못한 클러스터에 연결되어 있습니다."
    echo "💡 datadog-runner-cluster로 배포하시겠습니까? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "🔄 올바른 클러스터로 컨텍스트 변경 중..."
        kubectl config use-context kihyun_tam@datadog-runner-cluster.ap-northeast-2.eksctl.io
        echo "✅ 컨텍스트 변경 완료!"
    else
        echo "❌ 배포를 취소합니다."
        exit 1
    fi
else
    echo "✅ 올바른 EKS 클러스터($EXPECTED_CONTEXT)에 연결되어 있습니다."
fi

echo ""

# 배포 이력 로깅 함수 - 배포 추적 및 디버깅용
log_deployment() {
    local action="$1"          # START, SUCCESS, FAILED
    local service_name="$2"    # 서비스명
    local version_tag="$3"     # 이미지 태그
    local context="$4"         # 클러스터 컨텍스트
    local message="$5"         # 추가 메시지 (선택사항)
    
    # 로그 디렉토리 생성
    mkdir -p logs
    
    # 배포 이력 로그 파일
    local log_file="logs/deployment-history.log"
    
    # 사용자 정보 수집
    local user_info="${USER:-unknown}"
    if command -v git &> /dev/null && git config --get user.name &> /dev/null; then
        user_info="$(git config --get user.name) <$(git config --get user.email 2>/dev/null || echo 'no-email')>"
    fi
    
    # JSON 형태로 배포 이력 기록
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local git_hash=""
    if git rev-parse --git-dir > /dev/null 2>&1; then
        git_hash=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    fi
    
    # JSON 로그 엔트리 생성
    cat >> "$log_file" << EOF
{
  "timestamp": "$timestamp",
  "action": "$action",
  "service": "$service_name",
  "version": "$version_tag",
  "cluster_context": "$context",
  "user": "$user_info",
  "git_commit": "$git_hash",
  "aws_account": "${AWS_ACCOUNT_ID:-unknown}",
  "aws_region": "${AWS_REGION:-unknown}",
  "message": "$message"
}
EOF
    
    # 사람이 읽기 쉬운 형태로도 별도 기록
    local readable_log="logs/deployment-readable.log"
    echo "[$timestamp] $action: $service_name:$version_tag -> $context (by $user_info) $message" >> "$readable_log"
}

# 실패 시 로그 기록을 위한 trap 설정
cleanup_on_failure() {
    local exit_code=$?
    if [ $exit_code -ne 0 ] && [ -n "$SERVICE" ] && [ -n "$VERSION" ] && [ -n "$CURRENT_CONTEXT" ]; then
        log_deployment "FAILED" "$SERVICE" "$VERSION" "$CURRENT_CONTEXT" "배포 실패 (exit code: $exit_code)"
        echo "❌ 배포 실패가 로그에 기록되었습니다: logs/deployment-history.log"
    fi
}
trap cleanup_on_failure EXIT

# 동적 태그 생성 시스템 - 매번 고유한 태그로 캐시 무력화
# Git 사용 가능 시: git-{commit_hash} (추적 가능)
# Git 없을 시: dev-{timestamp} (개발 환경용)
if git rev-parse --git-dir > /dev/null 2>&1; then
    # Git이 있으면 커밋 해시 사용 - 코드 버전 추적 가능
    GIT_HASH=$(git rev-parse --short HEAD)
    VERSION="git-${GIT_HASH}"
else
    # Git이 없으면 타임스탬프 사용 - 빠른 개발 사이클 지원
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    VERSION="dev-${TIMESTAMP}"
fi

echo "🏷️  동적 생성된 고유 태그: $VERSION"

# 배포 시작 로그 기록
log_deployment "START" "$SERVICE" "$VERSION" "$CURRENT_CONTEXT" "배포 시작"
echo "📝 배포 시작이 로그에 기록되었습니다: logs/deployment-history.log"

# 1. Docker 이미지 빌드 - 캐시 활용으로 빌드 시간 단축
echo "🔨 $SERVICE 이미지 빌드 중..."

# 서비스별 설정 매핑 - 디렉토리명, 배포명, ECR 리포지토리명 불일치 해결
# 핵심 문제: ECR 리포지토리명과 로컬 서비스명이 다른 경우 처리 (예: frontend vs frontend-react)
case $SERVICE in
    "auth"|"auth-python")
        SERVICE_DIR="./services/auth-python"        # 소스코드 위치
        DEPLOYMENT_NAME="auth-python"               # K8s Deployment 이름
        CONTAINER_NAME="auth-python"                # K8s Container 이름
        ECR_SERVICE_NAME="auth-python"              # ECR 리포지토리 이름 (일치)
        ;;
    "chat"|"chat-node")
        SERVICE_DIR="./services/chat-node"
        DEPLOYMENT_NAME="chat-node"
        CONTAINER_NAME="chat-node"
        ECR_SERVICE_NAME="chat-node"                # ECR 리포지토리 이름 (일치)
        ;;
    "ranking"|"ranking-java")
        SERVICE_DIR="./services/ranking-java"
        DEPLOYMENT_NAME="ranking-java"
        CONTAINER_NAME="ranking-java"
        ECR_SERVICE_NAME="ranking-java"             # ECR 리포지토리 이름 (일치)
        ;;
    "frontend"|"frontend-react")
        SERVICE_DIR="./frontend-react"              # 실제 디렉토리 이름
        DEPLOYMENT_NAME="frontend"                  # K8s에서는 frontend로 배포
        CONTAINER_NAME="frontend"                   # Container 이름도 frontend
        ECR_SERVICE_NAME="frontend-react"           # 하지만 ECR 리포지토리는 frontend-react (불일치 해결)
        ;;
    "load-generator"|"loadgen")
        SERVICE_DIR="./services/load-generator"     # 소스코드 위치
        DEPLOYMENT_NAME="load-generator"            # K8s Deployment 이름
        CONTAINER_NAME="load-generator"             # K8s Container 이름
        ECR_SERVICE_NAME="load-generator"           # ECR 리포지토리 이름 (일치)
        ;;
    "api-gateway"|"gateway")
        SERVICE_DIR="./services/api-gateway"        # 소스코드 위치
        DEPLOYMENT_NAME="api-gateway"               # K8s Deployment 이름
        CONTAINER_NAME="api-gateway"                # K8s Container 이름
        ECR_SERVICE_NAME="api-gateway"              # ECR 리포지토리 이름 (일치)
        ;;
    *)
        echo "❌ 알 수 없는 서비스: $SERVICE"
        exit 1
        ;;
esac

# Docker 빌드 - 캐시 활용으로 개발 속도 향상
# BUILDKIT_INLINE_CACHE=1: 빌드 캐시를 이미지에 포함하여 재빌드 시 활용
docker buildx build \
    --platform linux/amd64 \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    -t datadog-runner/$ECR_SERVICE_NAME:$VERSION \
    $SERVICE_DIR --load

# ECR 이미지 태깅 - 정확한 ECR 리포지토리명 사용 (매핑 결과 적용)
ECR_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/$ECR_SERVICE_NAME:$VERSION"
ECR_LATEST="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/$ECR_SERVICE_NAME:latest"
docker tag datadog-runner/$ECR_SERVICE_NAME:$VERSION $ECR_IMAGE
docker tag datadog-runner/$ECR_SERVICE_NAME:$VERSION $ECR_LATEST

echo "📤 ECR에 고유 태그와 latest 태그로 푸시 중..."
docker push $ECR_IMAGE
docker push $ECR_LATEST

# 2. Kubernetes 이미지 업데이트 - 고유 태그로 확실한 업데이트 보장
# 장점: ImagePullPolicy: Always 없이도 새 이미지 배포 가능 (태그가 다르기 때문)
echo "🚀 Kubernetes deployment 업데이트 중..."
kubectl set image deployment/$DEPLOYMENT_NAME $CONTAINER_NAME=$ECR_IMAGE

# 3. 배포 완료 대기 - 안정적인 배포 확인
echo "⏳ 배포 완료 대기 중..."
kubectl rollout status deployment/$DEPLOYMENT_NAME --timeout=120s

# 배포 성공 로그 기록
log_deployment "SUCCESS" "$SERVICE" "$VERSION" "$CURRENT_CONTEXT" "배포 성공 완료"

# 정상 완료 시 실패 trap 해제 (중복 로그 방지)
trap - EXIT

echo "✅ $SERVICE 업데이트 완료!"
echo "🏷️  사용된 고유 태그: $VERSION (캐시 문제 해결됨)"
echo "📝 배포 성공이 로그에 기록되었습니다: logs/deployment-history.log"
echo "📊 배포 이력 확인: logs/deployment-readable.log"
echo "🌐 테스트: http://k8s-default-runnerin-d1d6c3a6d5-1329256805.ap-northeast-2.elb.amazonaws.com"
