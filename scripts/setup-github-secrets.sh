#!/bin/bash
# ============================================================================
# 🔐 GitHub Secrets 일괄 설정 스크립트
# ============================================================================
# 사용법:
#   1. 환경변수 설정:
#      export DD_API_KEY="your-datadog-api-key"
#      export DD_APP_KEY="your-datadog-app-key"  # 선택
#      export SLACK_WEBHOOK_URL="your-slack-webhook"  # 선택
#      export VITE_DD_RUM_APP_ID="your-rum-app-id"  # frontend용
#      export VITE_DD_RUM_CLIENT_TOKEN="your-rum-token"  # frontend용
#
#   2. 스크립트 실행:
#      ./setup-github-secrets.sh
# ============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 GitHub Secrets 일괄 설정 스크립트${NC}"
echo ""

# GitHub CLI 로그인 확인
if ! gh auth status &>/dev/null; then
    echo -e "${RED}❌ GitHub CLI 로그인이 필요합니다.${NC}"
    echo "   실행: gh auth login"
    exit 1
fi

# 저장소 목록
REPOS=(
    "varian-lee/datadog-runner-auth-python"
    "varian-lee/datadog-runner-chat-node"
    "varian-lee/datadog-runner-ranking-java"
    "varian-lee/datadog-runner-frontend"
    "varian-lee/datadog-runner-api-gateway"
    "varian-lee/datadog-runner-load-generator"
    "varian-lee/datadog-runner-infra"
)

# AWS Role ARN (고정값)
AWS_ROLE_ARN="arn:aws:iam::222066942551:role/kihyun-role-for-github-actions"

# 필수 환경변수 확인
if [ -z "$DD_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  DD_API_KEY가 설정되지 않았습니다.${NC}"
    echo -n "Datadog API Key를 입력하세요: "
    read -s DD_API_KEY
    echo ""
fi

echo -e "${GREEN}📋 설정할 Secrets:${NC}"
echo "   - AWS_ROLE_ARN: ${AWS_ROLE_ARN:0:50}..."
echo "   - DD_API_KEY: ${DD_API_KEY:0:10}..."
[ -n "$DD_APP_KEY" ] && echo "   - DD_APP_KEY: ${DD_APP_KEY:0:10}..."
[ -n "$SLACK_WEBHOOK_URL" ] && echo "   - SLACK_WEBHOOK_URL: (설정됨)"
[ -n "$VITE_DD_RUM_APP_ID" ] && echo "   - VITE_DD_RUM_APP_ID: ${VITE_DD_RUM_APP_ID:0:20}..."
[ -n "$VITE_DD_RUM_CLIENT_TOKEN" ] && echo "   - VITE_DD_RUM_CLIENT_TOKEN: (설정됨)"
echo ""

echo -e "${YELLOW}📦 대상 저장소:${NC}"
for repo in "${REPOS[@]}"; do
    echo "   - $repo"
done
echo ""

echo -n "계속하시겠습니까? (y/N): "
read -r confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "취소되었습니다."
    exit 0
fi

echo ""
echo -e "${BLUE}🚀 Secrets 설정 시작...${NC}"
echo ""

# 각 저장소에 Secrets 설정
for repo in "${REPOS[@]}"; do
    echo -e "${YELLOW}📦 $repo${NC}"
    
    # AWS_ROLE_ARN
    echo -n "   AWS_ROLE_ARN... "
    if gh secret set AWS_ROLE_ARN -b"$AWS_ROLE_ARN" -R "$repo" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
    
    # DD_API_KEY
    echo -n "   DD_API_KEY... "
    if gh secret set DD_API_KEY -b"$DD_API_KEY" -R "$repo" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
    fi
    
    # DD_APP_KEY (선택)
    if [ -n "$DD_APP_KEY" ]; then
        echo -n "   DD_APP_KEY... "
        if gh secret set DD_APP_KEY -b"$DD_APP_KEY" -R "$repo" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    fi
    
    # SLACK_WEBHOOK_URL (선택)
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        echo -n "   SLACK_WEBHOOK_URL... "
        if gh secret set SLACK_WEBHOOK_URL -b"$SLACK_WEBHOOK_URL" -R "$repo" 2>/dev/null; then
            echo -e "${GREEN}✓${NC}"
        else
            echo -e "${RED}✗${NC}"
        fi
    fi
    
    # Frontend 전용 Secrets
    if [[ "$repo" == *"frontend"* ]]; then
        if [ -n "$VITE_DD_RUM_APP_ID" ]; then
            echo -n "   VITE_DD_RUM_APP_ID... "
            if gh secret set VITE_DD_RUM_APP_ID -b"$VITE_DD_RUM_APP_ID" -R "$repo" 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${RED}✗${NC}"
            fi
        fi
        
        if [ -n "$VITE_DD_RUM_CLIENT_TOKEN" ]; then
            echo -n "   VITE_DD_RUM_CLIENT_TOKEN... "
            if gh secret set VITE_DD_RUM_CLIENT_TOKEN -b"$VITE_DD_RUM_CLIENT_TOKEN" -R "$repo" 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
            else
                echo -e "${RED}✗${NC}"
            fi
        fi
    fi
    
    echo ""
done

echo -e "${GREEN}✅ 완료!${NC}"
echo ""
echo -e "${BLUE}📋 설정된 Secrets 확인:${NC}"
for repo in "${REPOS[@]}"; do
    echo ""
    echo -e "${YELLOW}$repo:${NC}"
    gh secret list -R "$repo" 2>/dev/null || echo "   (접근 불가)"
done

