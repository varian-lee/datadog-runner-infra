#!/bin/bash

# 개선된 배포 스크립트 - Git 워크플로우 + Datadog Git 환경변수 자동 업데이트
# 기능:
# 1. 배포 전 Git 커밋/푸시 자동화
# 2. DD_GIT_COMMIT_SHA, DD_GIT_REPOSITORY_URL 환경변수 K8s에 자동 주입
# 3. 기존 동적 태깅 및 캐시 무력화 기능 유지
set -e

SERVICE=$1
if [ -z "$SERVICE" ]; then
    echo "❌ 서비스를 지정해주세요"
    echo "사용법: $0 <service_name>"
    echo "예시: $0 auth-python"
    echo ""
    echo "📊 Frontend (RUM) 배포 시 필요한 환경변수:"
    echo "   export VITE_DD_RUM_APP_ID=\"your_app_id\""
    echo "   export VITE_DD_RUM_CLIENT_TOKEN=\"your_client_token\""
    echo "   export VITE_DD_SITE=\"datadoghq.com\"  # 선택사항"
    echo "   export VITE_DD_ENV=\"demo\"           # 선택사항"
    echo "   $0 frontend-react"
    exit 1
fi

echo "🚀 Git + Datadog 통합 배포 스크립트 시작"
echo "📋 서비스: $SERVICE"
echo ""

# =============================================================================
# 1. Git 워크플로우 - 배포 전 변경사항 커밋/푸시
# =============================================================================

echo "🔍 Git 상태 확인 중..."

# Git 디렉토리 확인
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Git 저장소가 아닙니다. Git이 초기화된 디렉토리에서 실행해주세요."
    exit 1
fi

# Git 원격 저장소 URL 가져오기
GIT_REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
if [ -z "$GIT_REMOTE_URL" ]; then
    echo "❌ Git 원격 저장소가 설정되지 않았습니다."
    echo "💡 다음 명령으로 원격 저장소를 추가하세요:"
    echo "   git remote add origin <repository-url>"
    exit 1
fi

# GitHub URL 정규화 (ssh -> https 변환)
if [[ "$GIT_REMOTE_URL" == git@github.com:* ]]; then
    # ssh 형식을 https로 변환: git@github.com:user/repo.git -> https://github.com/user/repo
    DD_GIT_REPOSITORY_URL=$(echo "$GIT_REMOTE_URL" | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/\.git$//')
elif [[ "$GIT_REMOTE_URL" == https://github.com/* ]]; then
    # 이미 https 형식
    DD_GIT_REPOSITORY_URL=$(echo "$GIT_REMOTE_URL" | sed 's/\.git$//')
else
    DD_GIT_REPOSITORY_URL="$GIT_REMOTE_URL"
fi

echo "📋 Git 저장소: $DD_GIT_REPOSITORY_URL"

# 변경사항 확인
if git diff --quiet && git diff --cached --quiet; then
    echo "✅ 커밋할 변경사항이 없습니다."
else
    echo "📝 변경사항 발견! 자동 커밋을 진행합니다..."
    
    # 사용자 정보 확인
    if ! git config --get user.name > /dev/null || ! git config --get user.email > /dev/null; then
        echo "❌ Git 사용자 정보가 설정되지 않았습니다."
        echo "💡 다음 명령으로 설정하세요:"
        echo "   git config --global user.name 'Your Name'"
        echo "   git config --global user.email 'your.email@example.com'"
        exit 1
    fi
    
    # 변경사항 스테이징
    echo "📋 변경사항을 스테이징 중..."
    git add .
    
    # 커밋 메시지 생성
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    COMMIT_MESSAGE="🚀 Deploy $SERVICE - $TIMESTAMP

- 자동 배포 스크립트에 의한 커밋
- 서비스: $SERVICE
- 배포 시간: $TIMESTAMP
- Datadog Git 태깅 적용"
    
    echo "💾 커밋 중..."
    git commit -m "$COMMIT_MESSAGE"
    
    # 푸시
    echo "📤 GitHub에 푸시 중..."
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    git push origin "$CURRENT_BRANCH"
    
    echo "✅ Git 커밋/푸시 완료!"
fi

# 최신 커밋 해시 가져오기
DD_GIT_COMMIT_SHA=$(git rev-parse HEAD)
DD_GIT_COMMIT_SHORT=$(git rev-parse --short HEAD)

echo "🏷️  Git 커밋: $DD_GIT_COMMIT_SHORT ($DD_GIT_COMMIT_SHA)"
echo ""

# =============================================================================
# 2. AWS ECR 및 Kubernetes 설정 (기존 로직 유지)
# =============================================================================

# AWS ECR 설정
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=ap-northeast-2

# ECR 자동 로그인
echo "🔐 ECR 로그인 중..."
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

if aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}; then
    echo "✅ ECR 로그인 성공!"
else
    echo "❌ ECR 로그인 실패!"
    exit 1
fi

# Kubernetes 클러스터 컨텍스트 확인
echo "🔍 Kubernetes 클러스터 컨텍스트 확인 중..."
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "none")
EXPECTED_CONTEXT="datadog-runner-cluster"

echo "📋 현재 활성 컨텍스트: $CURRENT_CONTEXT"

if [[ "$CURRENT_CONTEXT" == "none" ]]; then
    echo "❌ Kubernetes 컨텍스트가 설정되지 않았습니다."
    exit 1
elif [[ "$CURRENT_CONTEXT" == "docker-desktop" ]]; then
    echo "⚠️  현재 docker-desktop(로컬) 컨텍스트에 연결되어 있습니다!"
    echo "🚨 실제 EKS 클러스터에 배포하려면 컨텍스트를 변경해야 합니다."
    echo ""
    echo "올바른 컨텍스트로 변경하시겠습니까? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
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

# =============================================================================
# 3. 동적 태그 생성 및 서비스 매핑 (기존 로직 유지)
# =============================================================================

# 동적 태그 생성 - Git 커밋 해시 포함
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
VERSION="dev-${TIMESTAMP}-${DD_GIT_COMMIT_SHORT}"

echo "🏷️  동적 생성된 고유 태그: $VERSION"

# 스크립트 실행 위치에 따른 경로 자동 감지
CURRENT_DIR="$(pwd)"

# 현재 작업 디렉토리 기준으로 판단
if [[ "$CURRENT_DIR" == *"/frontend-react"* ]] || [[ "$CURRENT_DIR" == *"/auth-python"* ]] || [[ "$CURRENT_DIR" == *"/chat-node"* ]] || [[ "$CURRENT_DIR" == *"/ranking-java"* ]] || [[ "$CURRENT_DIR" == *"/api-gateway"* ]] || [[ "$CURRENT_DIR" == *"/load-generator"* ]]; then
    # 개별 서비스에서 실행 (멀티루트)
    BASE_PATH="."
else
    # infra/scripts에서 실행 (기존 방식)  
    BASE_PATH="../.."
fi

# 서비스별 설정 매핑 (동적 경로 적용)
case $SERVICE in
    "auth"|"auth-python")
        if [ "$BASE_PATH" = "." ]; then
            SERVICE_DIR="."
            K8S_MANIFEST="../infra/infra/k8s/auth-python.yaml"
        else
            SERVICE_DIR="./auth-python"
            K8S_MANIFEST="./infra/infra/k8s/auth-python.yaml"
        fi
        DEPLOYMENT_NAME="auth-python"
        CONTAINER_NAME="auth-python"
        ECR_SERVICE_NAME="auth-python"
        ;;
    "chat"|"chat-node")
        if [ "$BASE_PATH" = "." ]; then
            SERVICE_DIR="."
            K8S_MANIFEST="../infra/infra/k8s/chat-node.yaml"
        else
            SERVICE_DIR="./chat-node"
            K8S_MANIFEST="./infra/infra/k8s/chat-node.yaml"
        fi
        DEPLOYMENT_NAME="chat-node"
        CONTAINER_NAME="chat-node"
        ECR_SERVICE_NAME="chat-node"
        ;;
    "ranking"|"ranking-java")
        if [ "$BASE_PATH" = "." ]; then
            SERVICE_DIR="."
            K8S_MANIFEST="../infra/infra/k8s/ranking-java.yaml"
        else
            SERVICE_DIR="./ranking-java"
            K8S_MANIFEST="./infra/infra/k8s/ranking-java.yaml"
        fi
        DEPLOYMENT_NAME="ranking-java"
        CONTAINER_NAME="ranking-java"
        ECR_SERVICE_NAME="ranking-java"
        ;;
    "frontend"|"frontend-react")
        if [ "$BASE_PATH" = "." ]; then
            SERVICE_DIR="."
            K8S_MANIFEST="../infra/infra/k8s/frontend.yaml"
        else
            SERVICE_DIR="./frontend-react"
            K8S_MANIFEST="./infra/infra/k8s/frontend.yaml"
        fi
        DEPLOYMENT_NAME="frontend"
        CONTAINER_NAME="frontend"
        ECR_SERVICE_NAME="frontend-react"
        ;;
    "load-generator"|"loadgen")
        if [ "$BASE_PATH" = "." ]; then
            SERVICE_DIR="."
            K8S_MANIFEST="../infra/infra/k8s/load-generator.yaml"
        else
            SERVICE_DIR="./load-generator"
            K8S_MANIFEST="./infra/infra/k8s/load-generator.yaml"
        fi
        DEPLOYMENT_NAME="load-generator"
        CONTAINER_NAME="load-generator"
        ECR_SERVICE_NAME="load-generator"
        ;;
    "api-gateway"|"gateway")
        if [ "$BASE_PATH" = "." ]; then
            SERVICE_DIR="."
            K8S_MANIFEST="../infra/infra/k8s/api-gateway.yaml"
        else
            SERVICE_DIR="./api-gateway"
            K8S_MANIFEST="./infra/infra/k8s/api-gateway.yaml"
        fi
        DEPLOYMENT_NAME="api-gateway"
        CONTAINER_NAME="api-gateway"
        ECR_SERVICE_NAME="api-gateway"
        ;;
    *)
        echo "❌ 알 수 없는 서비스: $SERVICE"
        exit 1
        ;;
esac

echo "📁 서비스 디렉토리: $SERVICE_DIR"
echo "📋 K8s 매니페스트: $K8S_MANIFEST"

# =============================================================================
# 4. Kubernetes 매니페스트 자동 업데이트 - Datadog Git 환경변수 주입
# =============================================================================

echo ""
echo "🔧 Kubernetes 매니페스트에 Datadog Git 환경변수 추가 중..."

# 백업 생성
cp "$K8S_MANIFEST" "${K8S_MANIFEST}.backup"
echo "💾 원본 파일 백업: ${K8S_MANIFEST}.backup"

# yq가 설치되어 있는지 확인
if ! command -v yq &> /dev/null; then
    echo "⚠️  yq가 설치되지 않았습니다. 매니페스트 수동 업데이트를 건너뜁니다."
    echo "💡 yq 설치: brew install yq"
    SKIP_MANIFEST_UPDATE=true
else
    # yq를 사용하여 환경변수 추가/업데이트 (기존 환경변수 보존) - 개선된 로직
    echo "📝 Datadog Git 환경변수 추가/업데이트 (기존 환경변수 보존)..."
    
    # 환경변수 섹션이 없으면 빈 배열로 초기화 (기존 것이 있으면 보존)
    if ! yq eval 'select(.kind == "Deployment") | .spec.template.spec.containers[0].env' "$K8S_MANIFEST" > /dev/null 2>&1; then
        yq eval '(select(.kind == "Deployment") | .spec.template.spec.containers[0].env) = []' -i "$K8S_MANIFEST"
    fi
    
    # DD_GIT_COMMIT_SHA 환경변수 추가/업데이트 (개선된 조건문)
    DD_GIT_SHA_EXISTS=$(yq eval 'select(.kind == "Deployment") | .spec.template.spec.containers[0].env[] | select(.name == "DD_GIT_COMMIT_SHA") | .name' "$K8S_MANIFEST" 2>/dev/null)
    if [[ -n "$DD_GIT_SHA_EXISTS" ]]; then
        # 이미 존재하면 값만 업데이트
        echo "🔄 DD_GIT_COMMIT_SHA 업데이트 중..."
        yq eval "(select(.kind == \"Deployment\") | .spec.template.spec.containers[0].env[] | select(.name == \"DD_GIT_COMMIT_SHA\")) |= .value = \"$DD_GIT_COMMIT_SHA\"" -i "$K8S_MANIFEST"
    else
        # 존재하지 않으면 새로 추가
        echo "➕ DD_GIT_COMMIT_SHA 추가 중..."
        yq eval "(select(.kind == \"Deployment\") | .spec.template.spec.containers[0].env) += [{\"name\": \"DD_GIT_COMMIT_SHA\", \"value\": \"$DD_GIT_COMMIT_SHA\"}]" -i "$K8S_MANIFEST"
    fi
    
    # DD_GIT_REPOSITORY_URL 환경변수 추가/업데이트 (개선된 조건문)
    DD_GIT_URL_EXISTS=$(yq eval 'select(.kind == "Deployment") | .spec.template.spec.containers[0].env[] | select(.name == "DD_GIT_REPOSITORY_URL") | .name' "$K8S_MANIFEST" 2>/dev/null)
    if [[ -n "$DD_GIT_URL_EXISTS" ]]; then
        # 이미 존재하면 값만 업데이트
        echo "🔄 DD_GIT_REPOSITORY_URL 업데이트 중..."
        yq eval "(select(.kind == \"Deployment\") | .spec.template.spec.containers[0].env[] | select(.name == \"DD_GIT_REPOSITORY_URL\")) |= .value = \"$DD_GIT_REPOSITORY_URL\"" -i "$K8S_MANIFEST"
    else
        # 존재하지 않으면 새로 추가
        echo "➕ DD_GIT_REPOSITORY_URL 추가 중..."
        yq eval "(select(.kind == \"Deployment\") | .spec.template.spec.containers[0].env) += [{\"name\": \"DD_GIT_REPOSITORY_URL\", \"value\": \"$DD_GIT_REPOSITORY_URL\"}]" -i "$K8S_MANIFEST"
    fi
    
    echo "📋 업데이트된 환경변수 확인:"
    yq eval 'select(.kind == "Deployment") | .spec.template.spec.containers[0].env | .[] | select(.name == "DD_GIT_COMMIT_SHA" or .name == "DD_GIT_REPOSITORY_URL")' "$K8S_MANIFEST"
    
    echo "✅ Datadog Git 환경변수 업데이트 완료!"
    echo "   - DD_GIT_COMMIT_SHA: $DD_GIT_COMMIT_SHA"
    echo "   - DD_GIT_REPOSITORY_URL: $DD_GIT_REPOSITORY_URL"
fi

# =============================================================================
# 5. Docker 이미지 빌드 및 푸시 (기존 로직 유지)
# =============================================================================

echo ""
echo "🔨 $SERVICE 이미지 빌드 중..."

# Docker 빌드
if [[ "$SERVICE" == "frontend-react" ]]; then
    # Frontend: RUM 환경변수를 빌드 인수로 전달
    docker buildx build \
        --platform linux/amd64 \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        --build-arg VITE_DD_RUM_APP_ID="${VITE_DD_RUM_APP_ID:-}" \
        --build-arg VITE_DD_RUM_CLIENT_TOKEN="${VITE_DD_RUM_CLIENT_TOKEN:-}" \
        --build-arg VITE_DD_SITE="${VITE_DD_SITE:-datadoghq.com}" \
        --build-arg VITE_DD_ENV="${VITE_DD_ENV:-demo}" \
        --build-arg VITE_APP_VERSION="${VITE_APP_VERSION:-0.1.0}" \
        -t datadog-runner/$ECR_SERVICE_NAME:$VERSION \
        $SERVICE_DIR --load
else
    # 다른 서비스들: 기본 빌드
    docker buildx build \
        --platform linux/amd64 \
        --build-arg BUILDKIT_INLINE_CACHE=1 \
        -t datadog-runner/$ECR_SERVICE_NAME:$VERSION \
        $SERVICE_DIR --load
fi

# ECR 이미지 태깅
ECR_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/$ECR_SERVICE_NAME:$VERSION"
ECR_LATEST="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/datadog-runner/$ECR_SERVICE_NAME:latest"
docker tag datadog-runner/$ECR_SERVICE_NAME:$VERSION $ECR_IMAGE
docker tag datadog-runner/$ECR_SERVICE_NAME:$VERSION $ECR_LATEST

echo "📤 ECR에 고유 태그와 latest 태그로 푸시 중..."
docker push $ECR_IMAGE
docker push $ECR_LATEST

# =============================================================================
# 6. Kubernetes 배포 (개선된 방식)
# =============================================================================

echo ""
echo "🚀 Kubernetes deployment 업데이트 중..."

if [ "$SKIP_MANIFEST_UPDATE" != "true" ]; then
    # 매니페스트 파일을 사용하여 apply (환경변수 포함)
    echo "📋 업데이트된 매니페스트 적용 중..."
    kubectl apply -f "$K8S_MANIFEST"
fi

# 이미지 태그 업데이트 (기존 방식 유지)
kubectl set image deployment/$DEPLOYMENT_NAME $CONTAINER_NAME=$ECR_IMAGE

# 배포 완료 대기
echo "⏳ 배포 완료 대기 중..."
kubectl rollout status deployment/$DEPLOYMENT_NAME --timeout=120s

# =============================================================================
# 7. 완료 및 정리
# =============================================================================

echo ""
echo "✅ $SERVICE 업데이트 완료!"
echo "🏷️  사용된 고유 태그: $VERSION"
echo "🔗 Git 커밋: $DD_GIT_COMMIT_SHORT"
echo "📋 Git 저장소: $DD_GIT_REPOSITORY_URL"
echo "🌐 테스트: http://k8s-default-runnerin-d1d6c3a6d5-1329256805.ap-northeast-2.elb.amazonaws.com"
echo ""
echo "📊 배포 요약:"
echo "   - Git 커밋/푸시: ✅"
echo "   - Docker 빌드: ✅"
echo "   - ECR 푸시: ✅"
echo "   - K8s 환경변수 업데이트: $([ "$SKIP_MANIFEST_UPDATE" = "true" ] && echo "⚠️ 건너뜀" || echo "✅")"
echo "   - K8s 배포: ✅"

# 백업 파일 정리 옵션
if [ "$SKIP_MANIFEST_UPDATE" != "true" ]; then
    echo ""
    echo "🗑️  매니페스트 백업 파일을 제거하시겠습니까? (y/N): "
    read -r cleanup_response
    if [[ "$cleanup_response" =~ ^[Yy]$ ]]; then
        rm "${K8S_MANIFEST}.backup"
        echo "✅ 백업 파일 제거 완료"
    else
        echo "📁 백업 파일 유지: ${K8S_MANIFEST}.backup"
    fi
fi

echo ""
echo "🎉 배포 완료! Datadog에서 Git 메타데이터와 함께 트레이스를 확인하세요."
