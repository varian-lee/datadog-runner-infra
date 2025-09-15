#!/bin/bash

# SSH 접근 옵션이 있는 EKS 클러스터 생성 스크립트

set -e

# 공통 함수 로드
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/common-functions.sh"

# 필수 도구 확인
check_required_tools "eksctl" "aws"

# AWS 환경 확인 (아직 확인되지 않은 경우)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    check_aws_environment
fi

# 설정 변수
CLUSTER_NAME=${CLUSTER_NAME:-datadog-runner-cluster}
NODE_GROUP_NAME="$CLUSTER_NAME-nodes"
NODE_TYPE=${NODE_TYPE:-t3.medium}
MIN_NODES=${MIN_NODES:-1}
MAX_NODES=${MAX_NODES:-3}
DESIRED_NODES=${DESIRED_NODES:-2}
SSH_KEY_NAME=${SSH_KEY_NAME:-tam-sandbox-key}

log_info "🎯 EKS 클러스터 생성 시작 (SSH 접근 포함)"
echo "   클러스터명: $CLUSTER_NAME"
echo "   지역: $AWS_REGION"
echo "   계정: $AWS_ACCOUNT_ID"
echo "   노드 타입: $NODE_TYPE"
echo "   노드 수: $MIN_NODES-$MAX_NODES (목표: $DESIRED_NODES)"
echo "   SSH 키: $SSH_KEY_NAME"
echo ""

# 클러스터 충돌 확인
if ! check_cluster_conflict "$CLUSTER_NAME" "$AWS_REGION"; then
    log_info "기존 클러스터를 사용합니다."
    exit 0
fi

# AWS에서 키 페어 존재 확인
log_info "AWS EC2 키 페어 확인 중..."
if ! aws ec2 describe-key-pairs --key-names "$SSH_KEY_NAME" --region "$AWS_REGION" &> /dev/null; then
    log_warning "AWS EC2에 '$SSH_KEY_NAME' 키 페어가 존재하지 않습니다."
    echo ""
    echo "다음 방법 중 선택하세요:"
    echo "1. 기존 .pem 키를 AWS에 등록"
    echo "2. SSH 없이 클러스터 생성 (./scripts/create-eks-cluster.sh 사용)"
    echo ""
    
    read -p "🤔 기존 .pem 키를 AWS에 등록하시겠습니까? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # SSH 키 설정 스크립트 실행
        if [ ! -f "./scripts/setup-ssh-key.sh" ]; then
            log_error "setup-ssh-key.sh 스크립트를 찾을 수 없습니다."
            exit 1
        fi
        
        ./scripts/setup-ssh-key.sh
        
        # public key를 AWS에 등록
        log_info "📤 AWS EC2에 키 페어 등록 중..."
        aws ec2 import-key-pair \
            --key-name "$SSH_KEY_NAME" \
            --public-key-material fileb://~/.ssh/id_rsa.pub \
            --region "$AWS_REGION"
        
        log_success "AWS EC2에 키 페어 등록 완료!"
    else
        log_info "SSH 없이 클러스터를 생성하려면 다음 스크립트를 사용하세요:"
        echo "  ./scripts/create-eks-cluster.sh"
        exit 0
    fi
fi

# EKS 클러스터 생성 (SSH 접근 포함)
log_info "🏗️  EKS 클러스터 생성 중... (약 15-20분 소요)"
eksctl create cluster \
    --name=$CLUSTER_NAME \
    --region=$AWS_REGION \
    --version=1.28 \
    --nodegroup-name=$NODE_GROUP_NAME \
    --node-type=$NODE_TYPE \
    --nodes-min=$MIN_NODES \
    --nodes-max=$MAX_NODES \
    --nodes=$DESIRED_NODES \
    --with-oidc \
    --ssh-access \
    --ssh-public-key=$SSH_KEY_NAME \
    --managed

# AWS Load Balancer Controller 설치
log_info "🔧 AWS Load Balancer Controller 설치 중..."

# OIDC 공급자 연결
eksctl utils associate-iam-oidc-provider --region=$AWS_REGION --cluster=$CLUSTER_NAME --approve

# IAM 역할 생성
eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --role-name="AmazonEKSLoadBalancerControllerRole" \
    --attach-policy-arn=arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess \
    --approve \
    --region=$AWS_REGION

# Helm을 통해 AWS Load Balancer Controller 설치
helm repo add eks https://aws.github.io/eks-charts
helm repo update

kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=$AWS_REGION \
    --set vpcId=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.resourcesVpcConfig.vpcId" --output text --region $AWS_REGION)

log_success "EKS 클러스터 생성 완료! (SSH 접근 가능)"
echo ""
log_info "SSH 접근 방법:"
echo "  # 노드 정보 확인"
echo "  kubectl get nodes -o wide"
echo "  "
echo "  # SSH 접근 예시"
echo "  ssh -i ~/.ssh/id_rsa ec2-user@<NODE_IP>"
echo ""
log_info "다음 명령어로 연결 확인:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
