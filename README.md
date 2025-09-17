# datadog-runner-infra

**Datadog Runner** 인프라 및 배포 스크립트 저장소입니다.

## 🔗 Multi-root Workspace
이 저장소는 Multi-root Workspace의 일부입니다:
- **🏠 워크스페이스**: /Users/kihyun.lee/workspace/datadog-runner-multiroot

## 📁 구성
- **infra/**: Kubernetes 매니페스트, Datadog 설정
- **scripts/**: 배포 및 개발 스크립트
- **sql/**: 데이터베이스 초기화 스크립트

## 🚀 사용법
```bash
# EKS 클러스터 생성
./scripts/create-eks-cluster.sh

# 전체 서비스 배포
./scripts/deploy-eks-complete.sh

# 개별 서비스 업데이트
./scripts/update-dev-image.sh <service-name>
```

## 📦 관련 마이크로서비스
- [datadog-runner-frontend](https://github.com/varian-lee/datadog-runner-frontend): frontend-react
- [datadog-runner-auth-python](https://github.com/varian-lee/datadog-runner-auth-python): auth-python
- [datadog-runner-chat-node](https://github.com/varian-lee/datadog-runner-chat-node): chat-node
- [datadog-runner-ranking-java](https://github.com/varian-lee/datadog-runner-ranking-java): ranking-java
- [datadog-runner-api-gateway](https://github.com/varian-lee/datadog-runner-api-gateway): api-gateway
- [datadog-runner-load-generator](https://github.com/varian-lee/datadog-runner-load-generator): load-generator

*마지막 업데이트: 2025-09-17*
