#!/bin/bash

# 기존 .pem 키에서 SSH 키 페어 설정 스크립트

set -e

# 공통 함수 로드
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common-functions.sh"

# .pem 키 파일 경로
PEM_KEY_PATH="${PEM_KEY_PATH:-~/tam-sandbox-key.pem}"
SSH_KEY_NAME="${SSH_KEY_NAME:-tam-sandbox-key}"

log_info "🔑 SSH 키 페어 설정 시작"
echo "   .pem 키 경로: $PEM_KEY_PATH"
echo "   SSH 키 이름: $SSH_KEY_NAME"
echo ""

# .pem 파일 존재 확인
if [ ! -f "$PEM_KEY_PATH" ]; then
    log_error ".pem 파일을 찾을 수 없습니다: $PEM_KEY_PATH"
    echo "올바른 경로를 지정하세요:"
    echo "  export PEM_KEY_PATH=~/your-key.pem"
    exit 1
fi

# SSH 디렉토리 생성
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# .pem 키를 SSH private key로 복사
cp "$PEM_KEY_PATH" ~/.ssh/id_rsa
chmod 600 ~/.ssh/id_rsa

# public key 추출
log_info "📤 Public key 추출 중..."
ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
chmod 644 ~/.ssh/id_rsa.pub

log_success "✅ SSH 키 페어 설정 완료!"
echo ""
log_info "생성된 파일들:"
echo "  Private key: ~/.ssh/id_rsa"
echo "  Public key: ~/.ssh/id_rsa.pub"
echo ""
log_info "이제 EKS 클러스터 생성 스크립트를 다시 실행할 수 있습니다:"
echo "  ./scripts/create-eks-cluster.sh"
