#!/bin/bash

# EKS 클러스터 생성 스크립트

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

log_info "🎯 EKS 클러스터 생성 시작"
echo "   클러스터명: $CLUSTER_NAME"
echo "   지역: $AWS_REGION"
echo "   계정: $AWS_ACCOUNT_ID"
echo "   노드 타입: $NODE_TYPE"
echo "   노드 수: $MIN_NODES-$MAX_NODES (목표: $DESIRED_NODES)"
echo ""

# 클러스터 충돌 확인
if ! check_cluster_conflict "$CLUSTER_NAME" "$AWS_REGION"; then
    log_info "기존 클러스터를 사용합니다."
    exit 0
fi

# EKS 클러스터 생성
echo "🏗️  EKS 클러스터 생성 중... (약 15-20분 소요)"
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
    --managed

# AWS Load Balancer Controller 설치
echo "🔧 AWS Load Balancer Controller 설치 중..."

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

log_success "EKS 클러스터 생성 완료!"
echo ""
log_info "다음 명령어로 연결 확인:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
