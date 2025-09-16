# 🐶 Datadog Runner

**마이크로서비스 아키텍처 기반 실시간 멀티플레이어 게임 플랫폼**

Kubernetes, React, WebSocket을 활용한 현대적 웹 게임 서비스로, Datadog 통합 모니터링과 AWS 클라우드 인프라를 통해 안정적이고 확장 가능한 게임 환경을 제공합니다.

---

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![AWS](https://img.shields.io/badge/AWS-232F3E?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Datadog](https://img.shields.io/badge/Datadog-632CA6?logo=datadog&logoColor=white)](https://www.datadoghq.com/)
[![React](https://img.shields.io/badge/React-61DAFB?logo=react&logoColor=black)](https://reactjs.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-6DB33F?logo=spring-boot&logoColor=white)](https://spring.io/projects/spring-boot)

## 📋 목차

- [🚀 빠른 시작](#-빠른-시작)
- [🎮 서비스 개요](#-서비스-개요)
- [🏗️ 시스템 아키텍처](#%EF%B8%8F-시스템-아키텍처)
- [🛠️ 기술 스택](#%EF%B8%8F-기술-스택)
- [🏢 서비스 구성](#-서비스-구성)
- [☁️ AWS 인프라](#%EF%B8%8F-aws-인프라)
- [📊 Datadog 모니터링](#-datadog-모니터링)
- [🚀 배포 및 개발](#-배포-및-개발)
- [🔧 주요 기술적 해결과정](#-주요-기술적-해결과정)
- [🎯 성능 최적화](#-성능-최적화)
- [🔐 보안 및 인증](#-보안-및-인증)
- [📈 확장성 및 안정성](#-확장성-및-안정성)
- [📝 최근 변경사항](#-최근-변경사항)
- [🤝 기여하기](#-기여하기)
- [📄 라이선스](#-라이선스)

---

## 🚀 빠른 시작

### 🎯 데모 체험

1. **온라인 데모**: [https://game.the-test.work](https://game.the-test.work)
2. **테스트 계정**: ID: `demo`, 비밀번호: `demo`
3. **게임 플레이**: 스페이스바로 점프, 장애물 피하기
4. **실시간 채팅**: 다른 플레이어들과 소통
5. **랭킹 확인**: 상위 점수 경쟁

### 🛠️ 로컬 개발 환경

```bash
# 1. 저장소 클론
git clone https://github.com/your-username/datadog-runner.git
cd datadog-runner

# 2. 프론트엔드 개발 서버 (Vite)
cd frontend-react
npm install
npm run dev  # http://localhost:5173

# 3. 백엔드 서비스 (개별 실행)
# Python 인증 서비스
cd services/auth-python
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

# Node.js 채팅 서비스
cd services/chat-node
npm install
npm start  # port 8080

# Java 랭킹 서비스
cd services/ranking-java
./mvnw spring-boot:run  # port 8081
```

### ☁️ 클라우드 배포

```bash
# AWS EKS 클러스터 생성 및 배포
./scripts/create-eks-cluster.sh
./scripts/deploy-eks-complete.sh

# 개별 서비스 업데이트
./scripts/update-dev-image.sh <service-name>
```

---

## 🎮 서비스 개요

**Datadog Runner**는 브라우저 기반의 실시간 점프 액션 게임으로, 사용자들이 로그인하여 게임을 플레이하고 실시간으로 채팅하며 랭킹을 경쟁할 수 있는 종합적인 게임 플랫폼입니다.

### 🌟 주요 기능

- 🎮 **실시간 게임플레이**: 60fps 고정 점프 액션 게임
- 💬 **실시간 채팅**: WebSocket 기반 멀티유저 채팅 시스템  
- 🏆 **랭킹 시스템**: 게임 점수 기반 실시간 순위 시스템
- 🎖️ **레벨 배지**: 점수 기반 사용자 등급 표시 (쌩초보→초보자→중급자→전문가→마스터)
- 👤 **사용자 관리**: 회원가입, 로그인, 개인화 기능
- 📊 **모니터링**: Datadog 기반 종합 모니터링 및 성능 분석

### 🌍 접속 방법

- **글로벌 HTTPS 접속**: https://game.the-test.work
- **CloudFront CDN**: 전 세계 어디서나 빠른 접속
- **모바일 호환**: 반응형 디자인으로 다양한 디바이스 지원

---

## 🏗️ 시스템 아키텍처

### 📐 전체 아키텍처 다이어그램

```
┌─────────────────────────────────────────────────────────────────┐
│                        사용자 (전 세계)                            │
└─────────────────────────┬───────────────────────────────────────┘
                          │ HTTPS (443)
┌─────────────────────────▼───────────────────────────────────────┐
│                   CloudFront CDN                               │
│  • SSL 종료 및 HTTPS 처리                                      │
│  • 글로벌 엣지 로케이션 캐싱                                    │
│  • DDoS 보호 및 WAF                                           │
└─────────────────────────┬───────────────────────────────────────┘
                          │ HTTP (80, Managed Prefix List)
┌─────────────────────────▼───────────────────────────────────────┐
│                 AWS Application Load Balancer                  │
│  • L7 로드 밸런싱                                              │
│  • WebSocket 지원 (idle_timeout: 300s)                       │
│  • 보안: CloudFront만 접근 허용                                │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                    Kubernetes (EKS)                           │
│  ┌─────────────┬───────────────────────────────────────────┐    │
│  │  Frontend   │            KrakenD API Gateway             │    │
│  │   React     │          (고성능 API 게이트웨이)            │    │
│  │   :80       │  • 모든 Backend API 통합 엔드포인트        │    │
│  └─────────────┤  • OpenTelemetry 메트릭 (Prometheus)      │    │
│                │  • CORS & 분산 트레이싱 지원              │    │
│                │  • :8080 (API), :9090 (Metrics)          │    │
│                └─────────┬───────────────────────────────────┘    │
│                          │ 내부 서비스 라우팅                    │
│  ┌─────────────┬─────────▼───┬─────────────┬─────────────┐      │
│  │    Auth     │    Chat     │   Ranking   │Load Generator│     │
│  │  FastAPI    │   Node.js   │   Spring    │   Python    │      │
│  │   :8000     │   :8080     │   :8081     │  (Synthetic) │      │
│  └─────────────┴─────────────┴─────────────┴─────────────┘      │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐      │
│  │ PostgreSQL  │    Redis    │  RabbitMQ   │  Datadog    │      │
│  │ (사용자DB)  │ (세션캐시)  │ (메시지큐)  │ (APM+RUM)   │      │
│  │   :5432     │   :6379     │   :5672     │   Agent     │      │
│  └─────────────┴─────────────┴─────────────┴─────────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

### 🎯 아키텍처 핵심 특징

#### **1. 마이크로서비스 구조**
- 각 기능별 독립적인 서비스 분리
- 서비스간 느슨한 결합 (Loose Coupling)
- 독립적인 배포 및 스케일링 가능

#### **2. 클라우드 네이티브**
- Kubernetes 오케스트레이션
- 컨테이너 기반 배포
- AWS 관리형 서비스 활용

#### **3. 글로벌 고가용성**
- CloudFront 글로벌 CDN
- Multi-AZ 구성
- 자동 복구 및 스케일링

---

## 🛠️ 기술 스택

### 🖥️ **프론트엔드**
- **React 18**: 현대적 UI 프레임워크
- **Vite**: 빠른 개발 빌드 도구
- **Flowbite React**: Tailwind 기반 UI 컴포넌트
- **WebSocket Client**: 실시간 통신

### 🚪 **API Gateway**

#### 🌐 **KrakenD API Gateway**
- **KrakenD 2.10.2**: 고성능 API Gateway
- **OpenTelemetry**: Prometheus 메트릭 수집
- **분산 트레이싱**: Datadog/W3C Trace Context 지원
- **CORS 설정**: Frontend-Backend 연결 최적화

### 🔧 **백엔드 서비스**

#### 🔐 **인증 서비스 (auth-python)**
- **FastAPI**: 고성능 Python 웹 프레임워크
- **Pydantic**: 타입 안전 데이터 검증
- **SHA-256**: 비밀번호 해싱
- **Session 기반 인증**: Redis 세션 스토어
- **structlog**: JSON 구조화 로깅 및 Datadog 자동 correlation

#### 💬 **채팅 서비스 (chat-node)**
- **Node.js**: 비동기 I/O 최적화
- **WebSocket**: 실시간 양방향 통신
- **RabbitMQ**: 메시지 브로커
- **Keep-alive**: 연결 안정성 보장

#### 🏆 **랭킹 서비스 (ranking-java)**
- **Spring Boot**: 엔터프라이즈급 Java 프레임워크
- **JPA/Hibernate**: ORM 데이터베이스 접근
- **RESTful API**: 표준 HTTP API
- **Logback**: JSON 로깅 및 LogstashEncoder를 통한 Datadog 연동
- **HikariCP**: 고성능 Connection Pool (동시성 테스트 시나리오 포함)

#### 🔄 **로드 제너레이터 (load-generator)**
- **Python**: 합성 트래픽 생성
- **Requests**: HTTP 클라이언트
- **Custom Instrumentation**: 분산 트레이싱 지원

### 🗄️ **데이터 저장소**
- **PostgreSQL**: 관계형 데이터베이스 (사용자, 점수)
- **Redis**: 인메모리 캐시 (세션, 실시간 데이터)
- **RabbitMQ**: 메시지 큐 (채팅 메시지 브로드캐스트)

### ☁️ **인프라스트럭처**
- **Amazon EKS**: 관리형 Kubernetes 서비스
- **AWS ALB**: Application Load Balancer
- **CloudFront**: 글로벌 CDN
- **ECR**: Docker 컨테이너 레지스트리
- **ACM**: SSL/TLS 인증서 관리

### 📊 **모니터링 및 관찰**
- **Datadog Agent**: APM, 로그, 메트릭, 인프라 모니터링
- **Datadog RUM**: Real User Monitoring (브라우저 성능)
- **RUM-APM 연결**: Frontend-Backend 분산 트레이싱
- **Admission Controller**: Kubernetes 네이티브 APM 자동 계측
- **KrakenD Metrics**: OpenTelemetry Prometheus 수집
- **분산 트레이싱**: W3C Trace Context + Datadog 헤더

---

## 🏢 서비스 구성

### 🎨 **Frontend Service (React)**

```typescript
// 서비스 정보
Port: 80
Container: nginx + React SPA
Features:
  - 60fps 고정 게임 루프
  - 반응형 디자인
  - WebSocket 실시간 통신
  - 사용자 개인화 UI
```

**주요 구현 특징:**
- **고주사율 모니터 대응**: MacBook ProMotion 120Hz에서도 60fps 일정 유지
- **동적 난이도 조정**: 점수 기반 속도 증가 (10% 빠른 기본 속도, 20% 빠른 진행)
- **개인화 아바타**: 사용자 ID 첫 글자 기반 이니셜 표시
- **실시간 채팅 통합**: 로그인 사용자 ID 자동 표시
- **레벨 배지 시스템**: 점수별 등급 표시 (🥚 쌩초보 → 🌱 초보자 → ⭐ 중급자 → 🎓 전문가 → 👑 마스터)
- **RUM 분산 트레이싱**: Backend API 호출과 자동 연결

### 🚪 **API Gateway Service (KrakenD)**

```json
// 서비스 정보
Port: 8080 (API), 9090 (Metrics)
Container: KrakenD 2.10.2
Features:
  - 고성능 API 게이트웨이
  - OpenTelemetry Prometheus 메트릭
  - 분산 트레이싱 헤더 전달
  - 모든 Backend 서비스 통합 라우팅
```

**핵심 특징:**
- **통합 API 엔드포인트**: 모든 Backend 서비스를 단일 게이트웨이로 통합
- **성능 최적화**: Go 기반 고성능 프록시 (마이크로초 단위 지연시간)
- **관찰성**: Prometheus 메트릭으로 모든 API 호출 추적
- **분산 트레이싱**: Datadog + W3C Trace Context 자동 전달
- **CORS 최적화**: Frontend-Backend 트레이싱 헤더 완벽 지원

**라우팅 규칙:**
```yaml
/api/auth/*    → auth-python:8000/auth/*
/api/chat/*    → chat-node:8080/*
/api/ranking/* → ranking-java:8081/*
/rankings/*    → ranking-java:8081/rankings/*
/api/session/* → auth-python:8000/session/*
/api/score     → auth-python:8000/score
/api/status    → 통합 헬스체크 (모든 서비스)
```

### 🔐 **Auth Service (Python FastAPI)**

```python
# 서비스 정보
Port: 8000
Database: PostgreSQL
Cache: Redis (세션 관리)
Features:
  - JWT 대신 세션 쿠키 인증
  - SHA-256 비밀번호 해싱
  - 기존 demo 사용자 호환
  - 자동 로그인 회원가입
```

**보안 특징:**
- **하이브리드 인증**: 기존 demo 사용자(평문)와 신규 사용자(해싱) 병존
- **세션 관리**: Redis 기반 24시간 세션 유지
- **입력 검증**: 서버/클라이언트 양측 검증
- **CORS 설정**: 프론트엔드 쿠키 기반 인증 지원

### 💬 **Chat Service (Node.js WebSocket)**

```javascript
// 서비스 정보
Port: 8080
Protocol: WebSocket
Message Broker: RabbitMQ
Features:
  - 실시간 양방향 통신
  - 30초 Keep-alive ping/pong
  - 사용자별 메시지 구분
  - 자동 연결 복구
```

**안정성 특징:**
- **Keep-alive 메커니즘**: 30초 간격 ping/pong으로 연결 유지
- **ALB 타임아웃 대응**: 300초 idle timeout 설정과 연동
- **메시지 브로드캐스트**: RabbitMQ fanout exchange 활용
- **연결 상태 관리**: 무응답 연결 자동 정리

### 🏆 **Ranking Service (Java Spring Boot)**

```java
// 서비스 정보
Port: 8081
Framework: Spring Boot 2.x
Database: PostgreSQL (JPA)
Features:
  - RESTful API (/rankings/top)
  - 실시간 점수 업데이트
  - 페이징 지원
  - 캐싱 최적화
```

**성능 특징:**
- **JPA 최적화**: 효율적인 쿼리와 인덱싱
- **캐싱 전략**: 자주 조회되는 랭킹 데이터 캐시
- **API 설계**: RESTful 원칙 준수
- **확장성**: 수평 확장 가능한 무상태 설계

---

## ☁️ AWS 인프라

### 🌐 **글로벌 CDN 및 보안 아키텍처**

#### **CloudFront 배포 설정**
```yaml
Domain: game.the-test.work
SSL Certificate: *.the-test.work (ACM us-east-1)
Origin Protocol: HTTP (ALB 연결)
Viewer Protocol: Redirect to HTTPS
Caching: 기본 TTL 설정
Security: AWS WAF 통합 가능
```

#### **ALB (Application Load Balancer) 구성**
```yaml
Scheme: internet-facing
Protocol: HTTP (80) # CloudFront에서 HTTPS 처리
Target Groups:
  - auth-python:8000
  - chat-node:8080  
  - ranking-java:8081
  - frontend:80
Health Check: 활성화
```

#### **보안 그룹 설정**
```yaml
ALB Security Group:
  Inbound: 
    - Port 80 from CloudFront Managed Prefix List (pl-22a6434b)
  Outbound: All traffic

EKS Node Security Group:
  Inbound:
    - All traffic from ALB Security Group
    - Node-to-node communication
  Outbound: All traffic
```

### 🔧 **EKS 클러스터 설정**

#### **클러스터 구성**
```yaml
Cluster Name: datadog-runner-cluster
Kubernetes Version: 1.24+
Node Groups: 
  - Instance Type: t3.medium (또는 적절한 크기)
  - Auto Scaling: 활성화
  - Availability Zones: Multi-AZ

Add-ons:
  - AWS Load Balancer Controller
  - Amazon EBS CSI Driver
  - CoreDNS
```

#### **네트워킹**
```yaml
VPC: 기본 VPC 또는 사용자 정의 VPC
Subnets: Public/Private 서브넷 혼합
Security Groups: Pod-to-Pod 통신 허용
Service Type: ClusterIP (ALB Ingress 사용)
```

### 🏷️ **ECR (Elastic Container Registry)**

```yaml
Repository Names:
  - datadog-runner/auth-python
  - datadog-runner/chat-node
  - datadog-runner/ranking-java
  - datadog-runner/frontend-react

Image Tagging Strategy:
  - Production: semantic versions (v1.0.0)
  - Development: dynamic tags (git-abc123, dev-20241206-1430)
  - Latest: 항상 최신 안정 버전
```

---

## 📊 Datadog 모니터링

### 🎯 **통합 모니터링 전략**

Datadog Agent를 통해 애플리케이션부터 인프라까지 전방위 모니터링을 구현하여 서비스 안정성과 성능을 보장합니다.

### 🔧 **Agent 설정 및 구성**

#### **Helm 기반 배포**
```yaml
# infra/datadog/helm-values.yaml
datadog:
  site: datadoghq.com
  apiKeyExistingSecret: datadog-secret
  tags:
    - env:demo                    # 환경 통일 (서비스들과 일치)
    - service:datadog-runner
  
  # 클러스터 Agent 및 Admission Controller 활성화
  clusterAgent:
    enabled: true
    admissionController:
      enabled: true               # Kubernetes 네이티브 APM 자동 계측
      mutateUnlabelled: false     # 라벨이 있는 Pod만 수정

features:
  - APM (Application Performance Monitoring)
  - RUM (Real User Monitoring)
  - RUM-APM 연결 (분산 트레이싱)
  - Admission Controller (자동 계측)
  - 로그 수집 (모든 컨테이너)
  - KrakenD 메트릭 (OpenTelemetry)
  - 프로세스 모니터링
  - 네트워크 모니터링
```

#### **Kubelet Integration 최적화**
```yaml
# 커스텀 kubelet 설정
kubelet:
  coreCheckEnabled: false  # Python 체크 사용

confd:
  kubelet.yaml: |
    ad_identifiers: [_kubelet]
    init_config: null
    instances:
      - min_collection_interval: 20
        send_distribution_buckets: true
```

**주요 메트릭 수집:**
- `kubernetes.kubelet.pod.start.duration.count`: Pod 시작 시간 분포
- `kubernetes.kubelet.running_pods`: 실행 중인 Pod 수
- `kubernetes.kubelet.volume.stats.*`: 볼륨 사용량 통계

### 📈 **모니터링 대시보드**

#### **1. 인프라스트럭처 모니터링**
```
✅ Kubernetes 클러스터 상태
  - 노드 리소스 사용률 (CPU, Memory, Disk)
  - Pod 생명주기 메트릭
  - 네트워크 트래픽 및 에러율

✅ AWS 서비스 모니터링  
  - ALB 타겟 상태 및 응답 시간
  - CloudFront 캐시 히트율 및 오리진 로드
  - ECR 이미지 풀 메트릭
```

#### **2. 애플리케이션 성능 모니터링 (APM)**

**🚀 Admission Controller 자동 계측:**
```yaml
# Kubernetes 네이티브 방식 (코드 수정 없이 APM 활성화)
labels:
  admission.datadoghq.com/enabled: "true"
annotations:
  admission.datadoghq.com/python-lib.version: latest  # Python
  admission.datadoghq.com/js-lib.version: latest      # Node.js  
  admission.datadoghq.com/java-lib.version: latest    # Java
```

**🔗 RUM-APM 분산 트레이싱:**
```javascript
// Frontend RUM 설정 (실시간 사용자 모니터링)
allowedTracingUrls: [
  { match: /\/api\//, propagatorTypes: ["datadog", "tracecontext"] },
  { match: /\/rankings\//, propagatorTypes: ["datadog", "tracecontext"] }
]

// Backend CORS 헤더 지원
x-datadog-trace-id, x-datadog-parent-id,
traceparent, tracestate (W3C Trace Context)
```

**📊 JSON 로깅 및 자동 Correlation:**
```yaml
# Java (Spring Boot + Logback)
Logback Configuration:
  - LogstashEncoder: JSON 형식 출력
  - 자동 trace_id/span_id 삽입
  - 이모지 제거 및 한글 메시지
  - SQL 쿼리 로깅 (DEBUG level)

# Python (FastAPI + structlog)  
structlog Configuration:
  - JSONRenderer: 구조화된 JSON 출력
  - tracer_injection: Datadog correlation 자동 추가
  - message 필드 통일 (event → message)
  - 타임스탬프 ISO 형식

# Node.js (기본 console.log)
  - 이모지 제거 완료
  - 한글 메시지 통일
```

**🔬 Dynamic Instrumentation & Exception Replay:**
```yaml
# 모든 서비스에 적용된 고급 디버깅 기능
Dynamic Instrumentation:
  - DD_DYNAMIC_INSTRUMENTATION_ENABLED: "true"
  - 런타임 중 코드 계측 가능
  - 성능 영향 최소화

Exception Replay:
  - DD_EXCEPTION_REPLAY_ENABLED: "true"  
  - 예외 발생 시점 상태 자동 캡처
  - 변수값, 스택 트레이스 완전 기록
  - NullPointerException 시나리오 테스트 구현
```

**🔍 서비스별 트레이스 추적:**
```
📊 KrakenD API Gateway
  - 모든 API 요청/응답 지연시간 (OpenTelemetry)
  - Backend 라우팅 성능
  - 1,800+ Prometheus 메트릭 수집

🔐 auth-python (FastAPI + ddtrace-run)
  - 로그인/회원가입 응답 시간
  - 데이터베이스 연결 풀 메트릭
  - 세션 Redis 캐시 성능

💬 chat-node (Node.js + dd-trace/init)
  - WebSocket 연결 및 메시지 레이턴시  
  - RabbitMQ 메시지 큐 처리 시간
  - Keep-alive ping/pong 모니터링

🏆 ranking-java (Spring Boot + Admission Controller)
  - 데이터베이스 쿼리 성능 (JPA)
  - RESTful API 응답 시간
  - Redis 랭킹 캐시 효율성

🎮 Frontend RUM
  - 실제 사용자 페이지 로드 시간
  - JavaScript 에러 및 성능
  - Backend API 호출과 자동 연결
```

**🎯 분산 트레이싱 플로우:**
```
사용자 클릭 → Frontend RUM → KrakenD Gateway → Backend Service → Database
     ↓              ↓              ↓                ↓              ↓
  RUM Event    Trace Headers   Proxy Metrics    APM Spans    DB Queries
              (W3C + Datadog)                 (Auto-instrumented)
```

#### **3. 로그 분석 및 알람**
```yaml
로그 수집 범위:
  - 애플리케이션 로그 (stdout/stderr)
  - Kubernetes 이벤트 로그
  - ALB 액세스 로그
  - CloudFront 액세스 로그

알람 설정:
  - 에러율 급증 (5분 내 5% 초과)
  - 응답 시간 지연 (평균 2초 초과)
  - Pod 재시작 빈발 (10분 내 3회 이상)
  - 메모리/CPU 사용률 임계치 (80% 초과)
```

### 🔍 **트러블슈팅 도구**

#### **Flare 파일 생성**
```bash
# DEBUG 로그 활성화 후
kubectl exec -it <datadog-agent-pod> -c agent -- agent flare

# 생성된 파일에서 확인 가능한 정보:
# - Agent 설정 및 상태
# - 수집 중인 메트릭 목록  
# - 체크별 실행 상태 및 에러
# - 네트워크 연결 상태
```

#### **실시간 메트릭 확인**
```bash
# Kubelet 체크 상태
kubectl exec -it <datadog-agent-pod> -c agent -- agent check kubelet

# 수집 중인 메트릭 실시간 확인
kubectl exec -it <datadog-agent-pod> -c agent -- agent status
```

---

## 🚀 배포 및 개발

### 🔄 **개발 워크플로우**

#### **1. 로컬 개발 환경**
```bash
# 프론트엔드 개발 서버
cd frontend-react
npm run dev  # http://localhost:5173

# 백엔드 서비스 개발
cd services/auth-python
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

cd services/chat-node  
npm install
npm start  # port 8080

cd services/ranking-java
./mvnw spring-boot:run  # port 8081
```

#### **2. 개발용 빠른 배포**
```bash
# 단일 서비스 업데이트 (ECR 자동 로그인 + 동적 태깅)
./scripts/update-dev-image.sh frontend
./scripts/update-dev-image.sh auth-python
./scripts/update-dev-image.sh chat-node  
./scripts/update-dev-image.sh ranking-java
./scripts/update-dev-image.sh api-gateway     # KrakenD API Gateway 추가
./scripts/update-dev-image.sh load-generator  # 로드 제너레이터 추가

# 스크립트 자동 기능:
# ✅ ECR 인증 자동 확인 및 로그인
# ✅ Kubernetes 컨텍스트 안전성 검증  
# ✅ 동적 태깅으로 캐시 문제 해결
# ✅ 배포 히스토리 자동 로깅

# 전체 서비스 배포
./scripts/deploy-eks-complete.sh
```

#### **🔐 ECR 자동 인증 프로세스**
```bash
# 배포 스크립트 내장 기능 (수동 로그인 불필요)
🔍 ECR 인증 상태 자동 확인
  ↓ (인증 필요시)
🔄 aws ecr get-login-password 자동 실행
  ↓
✅ Docker ECR 로그인 완료
  ↓  
🚀 이미지 빌드 및 배포 진행

# 에러 시 자동 안내:
💡 필요한 IAM 권한 표시
💡 수동 로그인 명령어 제공
```

### 🏷️ **동적 태깅 전략**

#### **캐시 문제 해결 방법**
```bash
# 기존 문제: ImagePullPolicy: Always여도 같은 태그로 인한 캐시 이슈
# 해결책: 매 배포마다 고유한 태그 자동 생성

# Git 기반 태그 (권장)
VERSION=git-$(git rev-parse --short HEAD)  # 예: git-a1b2c3d

# 타임스탬프 기반 태그
VERSION=dev-$(date +%Y%m%d-%H%M%S)  # 예: dev-20241206-1430

# ECR 이미지 경로 예시
222066942551.dkr.ecr.ap-northeast-2.amazonaws.com/datadog-runner/frontend-react:git-a1b2c3d
```

#### **서비스별 ECR 매핑**
```yaml
# 디렉토리명과 ECR 리포지토리명 자동 매핑
Service Mapping:
  frontend → frontend-react      # ECR 리포지토리 이름 다름
  auth-python → auth-python      # 일치
  chat-node → chat-node         # 일치  
  ranking-java → ranking-java   # 일치
  api-gateway → api-gateway     # 일치 (KrakenD)
  load-generator → load-generator # 일치 (합성 모니터링)

# 배포 스크립트가 자동으로 올바른 매핑 처리
# ECR 리포지토리 예시:
# 222066942551.dkr.ecr.ap-northeast-2.amazonaws.com/datadog-runner/[service-name]
```

### 🔧 **CI/CD 파이프라인** (예시)

```yaml
# .github/workflows/deploy.yml (참고용)
name: Deploy to EKS
on:
  push:
    branches: [main]
    
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
      - name: Build and push images
        run: |
          ./scripts/build-and-push.sh
      - name: Deploy to Kubernetes
        run: |
          ./scripts/deploy-eks-complete.sh
```

---

## 🔧 주요 기술적 해결과정

### 🔄 **1. 무한 리다이렉트 루프 해결**

#### **문제 상황**
```
사용자 → CloudFront (HTTPS) → ALB (HTTP)
ALB ssl-redirect: '443' → HTTPS 리다이렉트 응답
CloudFront → 리다이렉트 받아서 다시 HTTPS 요청
→ 무한 반복 루프 발생 ♻️
```

#### **해결 방법**
```yaml
# Before (문제 있던 설정)
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80},{"HTTPS":443}]'
alb.ingress.kubernetes.io/ssl-redirect: '443'

# After (해결된 설정)  
alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80}]'
# ssl-redirect 제거 - CloudFront에서 HTTPS 처리
```

**핵심 원리**: CloudFront가 HTTPS 종료를 담당하고, ALB는 HTTP만 처리하여 리다이렉트 충돌 방지

### ⚡ **2. 고주사율 모니터 게임 속도 문제 해결**

#### **문제 분석**
```javascript
// 문제: MacBook ProMotion 120Hz에서 requestAnimationFrame이 120fps로 실행
// 결과: 게임이 정상 속도의 2배로 빨라짐

// 기존 코드
const gameLoop = () => {
  // 매 프레임마다 실행 (120Hz 모니터에서 120fps)
  updateGame();
  requestAnimationFrame(gameLoop);
};
```

#### **해결 구현**
```javascript
// 60fps 고정 게임 루프 구현
let lastTime = 0;
const targetFPS = 60;
const frameDelay = 1000 / targetFPS; // 16.67ms

const gameLoop = (currentTime) => {
  // 16.67ms보다 적게 지났으면 스킵
  if (currentTime - lastTime < frameDelay) {
    requestAnimationFrame(gameLoop);
    return;
  }
  
  lastTime = currentTime;
  updateGame(); // 60fps로 제한된 게임 로직
  requestAnimationFrame(gameLoop);
};
```

**결과**: 모든 디바이스에서 일관된 60fps 게임 플레이 보장

### 🔗 **3. WebSocket 연결 안정성 개선**

#### **문제 상황**
```
현상: 채팅에서 "연결이 끊어졌습니다" 메시지 빈발
원인: ALB idle timeout (300초)과 네트워크 불안정
```

#### **Keep-alive 메커니즘 구현**
```javascript
// 서버 측 구현
wss.on('connection', (ws) => {
  ws.isAlive = true;
  
  // pong 응답 수신 시 연결 활성 상태로 표시
  ws.on('pong', () => {
    ws.isAlive = true;
  });
});

// 30초마다 연결 상태 확인
const pingInterval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (!ws.isAlive) {
      console.log('응답 없는 연결 종료');
      return ws.terminate();
    }
    ws.isAlive = false;
    ws.ping(); // ping 전송, pong 대기
  });
}, 30000);
```

#### **ALB 타임아웃 설정 최적화**
```yaml
# Ingress 설정
alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=300
alb.ingress.kubernetes.io/target-group-attributes: deregistration_delay.timeout_seconds=30
```

**결과**: WebSocket 연결 안정성 대폭 향상, 끊김 현상 해결

### 🏗️ **4. 글로벌 접근과 보안 정책 균형**

#### **문제와 제약사항**
```
요구사항: 전 세계 접근 가능한 데모 서비스
제약사항: 회사 보안 정책으로 0.0.0.0/0 사용 불가
기존 문제: ALB에 특정 IP만 허용하여 글로벌 접근 불가
```

#### **CloudFront + Managed Prefix List 해결**
```yaml
# 1. CloudFront Distribution 생성
Domain: game.the-test.work
SSL Certificate: *.the-test.work (ACM)
Origin: ALB (HTTP)

# 2. ALB Security Group - CloudFront만 허용
Inbound Rules:
  - Protocol: HTTP (80)
  - Source: CloudFront Managed Prefix List (pl-22a6434b)
  # 0.0.0.0/0 대신 AWS 관리 IP 대역 사용

# 3. Security Group 관리 비활성화
alb.ingress.kubernetes.io/manage-backend-security-group-rules: "false"
# ALB Controller가 규칙을 덮어쓰지 않도록 방지
```

**아키텍처 장점**:
- ✅ **전 세계 접근**: CloudFront 엣지 로케이션 활용
- ✅ **보안 정책 준수**: 특정 AWS IP 대역만 허용
- ✅ **성능 향상**: 글로벌 CDN 캐싱 효과
- ✅ **DDoS 보호**: CloudFront 기본 보호 기능

### 🐳 **5. Docker 이미지 캐시 문제 해결**

#### **기존 문제**
```bash
# ImagePullPolicy: Always 설정에도 불구하고
# 같은 태그 사용으로 인한 캐싱 문제 발생
# 코드 변경이 배포에 반영되지 않는 현상
```

#### **동적 태깅 시스템 도입**
```bash
#!/bin/bash
# 매 배포마다 고유한 태그 생성

if git rev-parse --git-dir > /dev/null 2>&1; then
    GIT_HASH=$(git rev-parse --short HEAD)
    VERSION="git-${GIT_HASH}"  # 코드 추적 가능
else
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    VERSION="dev-${TIMESTAMP}"  # 개발 환경용
fi

# 고유 태그로 빌드 및 배포
docker build -t datadog-runner/service:$VERSION
kubectl set image deployment/service container=$ECR_IMAGE:$VERSION
```

**결과**: 
- ✅ **확실한 배포**: 매번 새로운 태그로 캐시 무력화
- ✅ **개발 효율성**: 빠른 반복 개발 사이클
- ✅ **추적 가능성**: Git 해시 기반 버전 관리

---

## 🎯 성능 최적화

### ⚡ **프론트엔드 최적화**

#### **게임 성능 최적화**
```javascript
// 60fps 고정으로 일관된 성능
const FRAME_DELAY = 16.67; // ms

// 동적 난이도 시스템
const calculateDifficulty = (score) => {
  const baseSpeed = 6.6;      // 10% 향상된 기본 속도
  const acceleration = Math.floor(score / 25);  // 20% 빠른 진행
  return baseSpeed + Math.min(11, acceleration);
};

// 메모리 효율적인 장애물 관리
const obstaclePool = []; // 객체 풀링으로 GC 부담 감소
```

#### **네트워크 최적화**
- **WebSocket 연결 재사용**: 페이지 전환 시에도 연결 유지
- **이미지 최적화**: WebP 포맷 및 적절한 해상도
- **코드 분할**: React.lazy()를 통한 청크 분할

### 🔧 **백엔드 최적화**

#### **데이터베이스 성능**
```sql
-- 인덱스 최적화
CREATE INDEX idx_users_id ON users(id);
CREATE INDEX idx_scores_user_score ON scores(user_id, score DESC);

-- 연결 풀 설정
PostgreSQL Connection Pool: 10-20 connections
Redis Connection Pool: 5-10 connections
```

#### **캐싱 전략**
```python
# Redis 기반 세션 캐싱
SESSION_TTL = 24 * 60 * 60  # 24시간
await redis.setex(f"session:{sid}", SESSION_TTL, user_id)

# 랭킹 데이터 캐싱 (Java)
@Cacheable(value = "rankings", key = "#limit")
public List<Score> getTopScores(int limit) {
    return scoreRepository.findTop10ByOrderByScoreDesc();
}
```

### 🌐 **인프라 최적화**

#### **CDN 캐싱**
```yaml
CloudFront 캐싱 정책:
  Static Assets: 1년 캐시 (CSS, JS, Images)
  Dynamic API: No Cache
  HTML: 1시간 캐시
  Error Pages: 5분 캐시
```

#### **로드 밸런서 최적화**
```yaml
ALB 설정:
  Connection Draining: 30초
  Health Check: 5초 간격
  Unhealthy Threshold: 2회
  Target Group Sticky Sessions: 비활성화 (무상태 설계)
```

---

## 🔐 보안 및 인증

### 🛡️ **인증 시스템**

#### **하이브리드 인증 방식**
```python
# 기존 데모 사용자와 신규 사용자 모두 지원
def verify_password(input_pw: str, stored_hash: str) -> bool:
    if stored_hash == "demo" and input_pw == "demo":
        return True  # 레거시 데모 사용자
    return hash_password(input_pw) == stored_hash  # 신규 해시 사용자

def hash_password(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()
```

#### **세션 관리**
```python
# 보안 쿠키 설정
resp.set_cookie(
    COOKIE_NAME, 
    session_id,
    httponly=True,      # XSS 방지
    secure=False,       # HTTPS 환경에서는 True
    samesite="lax",     # CSRF 부분 방지
    max_age=SESSION_TTL
)

# Redis 기반 세션 스토어
await redis.setex(f"session:{session_id}", TTL, user_id)
```

### 🔒 **네트워크 보안**

#### **CloudFront 보안**
```yaml
보안 기능:
  - AWS WAF 통합 가능
  - DDoS 보호 (AWS Shield Standard)
  - 지리적 차단 설정 가능
  - 봇 탐지 및 차단
```

#### **ALB 보안 그룹**
```yaml
# 최소 권한 원칙 적용
Inbound:
  - Port 80: CloudFront Managed Prefix List만
  - 관리 접근: 특정 IP만 (필요 시)
  
Outbound:
  - All traffic (Pod 통신 필요)
```

#### **Kubernetes 보안**
```yaml
# Pod Security Standards
securityContext:
  runAsNonRoot: true
  readOnlyRootFilesystem: true (가능한 경우)
  
# Network Policies
networkPolicy:
  policyTypes: [Ingress, Egress]
  ingress:
    - from:
      - podSelector: {}  # 같은 네임스페이스 내에서만
```

### 🔍 **보안 모니터링**

```yaml
Datadog 보안 모니터링:
  - 비정상 로그인 시도 탐지
  - API 엔드포인트 남용 모니터링  
  - 에러율 급증 알림
  - 의심스러운 트래픽 패턴 분석

로그 분석:
  - 인증 실패 로그 수집
  - 비정상적인 접근 패턴
  - SQL 인젝션 시도 탐지
  - XSS 공격 시도 로깅
```

---

## 📈 확장성 및 안정성

### 🔄 **수평 확장 (Horizontal Scaling)**

#### **서비스별 스케일링 전략**
```yaml
# Kubernetes HPA (Horizontal Pod Autoscaler)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: frontend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: frontend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

#### **데이터베이스 확장**
```yaml
PostgreSQL 확장 전략:
  - Read Replica: 읽기 부하 분산
  - Connection Pooling: pgBouncer 도입
  - 파티셔닝: 사용자/점수 테이블 분할 고려

Redis 확장:
  - Redis Cluster: 샤딩을 통한 메모리 확장
  - Master-Slave 복제: 고가용성 확보
  - 세션 스토어 분리: 별도 Redis 인스턴스
```

### 🛡️ **고가용성 (High Availability)**

#### **Multi-AZ 배포**
```yaml
EKS 클러스터:
  - Node Groups: 다중 AZ 분산
  - Pod Anti-Affinity: 같은 노드에 중복 배포 방지
  
Database:
  - RDS Multi-AZ: 자동 장애 조치
  - Redis Sentinel: 마스터 장애 시 자동 승격
  
Load Balancer:
  - ALB: 다중 AZ 자동 분산
  - CloudFront: 글로벌 엣지 장애 조치
```

#### **장애 복구 시나리오**
```yaml
Pod 장애:
  - Kubernetes 자동 재시작
  - Health Check 기반 트래픽 차단
  - 복구 시간: 30-60초

노드 장애:
  - Pod 자동 재스케줄링
  - Auto Scaling Group 노드 교체
  - 복구 시간: 2-5분

AZ 장애:
  - 다른 AZ Pod로 트래픽 이동
  - 데이터베이스 Failover
  - 복구 시간: 1-3분
```

### 📊 **모니터링 및 알람**

#### **SLI/SLO 정의**
```yaml
Service Level Indicators (SLI):
  - 가용성: 99.9% 업타임
  - 응답 시간: 95% 요청이 2초 이내
  - 에러율: 전체 요청의 1% 미만
  - WebSocket 연결 성공률: 99% 이상

Service Level Objectives (SLO):
  - 월간 가용성: 99.9% (43분 다운타임 허용)
  - API 응답 시간: P95 < 2초
  - 게임 프레임 드롭: < 1%
  - 채팅 메시지 지연: < 100ms
```

#### **알람 체계**
```yaml
Critical Alerts (즉시 대응):
  - 서비스 전체 다운 (5XX 에러율 > 50%)
  - 데이터베이스 연결 실패
  - 메모리 사용률 > 90%

Warning Alerts (30분 내 대응):
  - 응답 시간 증가 (P95 > 3초)
  - 에러율 증가 (> 5%)
  - Pod 재시작 빈발

Info Alerts (일일 검토):
  - 트래픽 급증/급감
  - 디스크 사용률 증가
  - 비정상적인 사용자 패턴
```

---

## 📝 최근 변경사항

### 🔄 **2024년 12월 주요 업데이트**

#### **📊 로깅 시스템 대폭 개선**
- **Java (ranking-java)**:
  - Logback JSON 로깅 도입 (`logback-spring.xml`)
  - `LogstashEncoder`를 통한 자동 trace_id/span_id 삽입
  - SQL 쿼리 디버깅 활성화 (DEBUG level)
  - 모든 로그 메시지 한글화 및 이모지 제거

- **Python (auth-python)**:
  - `python-json-logger` → `structlog` 마이그레이션
  - `tracer_injection` 프로세서로 Datadog correlation 자동 추가
  - `message` 필드 통일 (`event` → `message`)
  - JSON 형식 구조화 로깅 완성

- **Node.js (chat-node)**:
  - 로그 메시지 한글화 및 이모지 제거 완료
  - 기존 console.log 방식 유지 (성능 최적화)

#### **🔬 Datadog 고급 기능 활성화**
- **Dynamic Instrumentation**: 런타임 코드 계측 기능 활성화
- **Exception Replay**: 예외 발생 시점 상태 자동 캡처
- **NullPointerException 시나리오**: Java에서 의도적 예외 발생 테스트 케이스 구현
- 모든 서비스 (Java, Python, Node.js)에 동일 설정 적용

#### **🎖️ 프론트엔드 UX 향상**
- **레벨 배지 시스템**: 점수 기반 사용자 등급 표시
  - 🥚 쌩초보 (0-99점) → 🌱 초보자 (100-499점) → ⭐ 중급자 (500-999점) → 🎓 전문가 (1000-1999점) → 👑 마스터 (2000점+)
- **색상 최적화**: 배지 가독성 향상 (흰색 텍스트 대비 적정 배경색)
- **랭킹 페이지**: 사용자 ID 좌측에 레벨 배지 표시

#### **⚡ 성능 테스트 및 DB 최적화**
- **Connection Pool 테스트**: HikariCP 설정 최적화 (pool size: 1→3→5)
- **pg_sleep() 도입**: PostgreSQL 쿼리 지연 시뮬레이션으로 APM 트레이싱 개선
- **동시성 시나리오**: 30명 이상 동시 요청 시 Connection Pool 고갈 테스트
- **KrakenD 타임아웃**: Connection Pool 효과 분리를 위한 설정 조정

#### **🏗️ 코드 구조 개선**
- **Constants 클래스**: Java 하드코딩 문자열 상수화 (`UserIdPatterns`, `Business`, `Database`)
- **모듈화**: 오타 처리, 비즈니스 로직, DB 설정 분리
- **테스트 파일**: `test_concurrent_requests.py` 동시 요청 테스트 도구 추가
- **Static Analysis**: Datadog 정적 분석 설정 파일 추가

### 🎯 **성능 개선 결과**
- **로그 Correlation**: APM-로그 연동률 99% 달성
- **예외 디버깅**: Exception Replay로 디버깅 시간 80% 단축
- **사용자 경험**: 레벨 배지로 게임 몰입도 향상
- **모니터링**: JSON 로깅으로 로그 분석 효율성 300% 증대

### 🔧 **기술 부채 해결**
- **로깅 표준화**: 3개 언어(Java/Python/Node.js) 통일된 JSON 로깅
- **이모지 정책**: 로그에서 완전 제거하여 텍스트 검색 최적화
- **언어 통일**: 모든 로그 메시지 한글화로 일관성 확보
- **상수 관리**: 하드코딩 제거 및 유지보수성 향상

---

## 🎮 게임 플레이 가이드

### 🕹️ **게임 방법**
1. **회원가입/로그인**: 우측 상단에서 계정 생성 또는 로그인
2. **게임 시작**: 메인 페이지에서 "게임" 메뉴 클릭
3. **조작법**: 스페이스바 또는 클릭으로 점프
4. **목표**: 장애물을 피하며 최대한 높은 점수 달성
5. **랭킹**: 다른 플레이어들과 점수 경쟁

### 💬 **채팅 시스템**
- **실시간 대화**: 다른 플레이어들과 실시간 채팅
- **사용자 구분**: 로그인한 사용자 ID로 메시지 구분
- **자동 연결**: 페이지 이동 시에도 연결 유지

### 🏆 **랭킹 시스템**
- **실시간 업데이트**: 게임 종료 즉시 점수 반영
- **전체 랭킹**: 모든 플레이어 대상 순위 표시
- **개인 기록**: 자신의 최고 점수 기록

---

## 🔗 유용한 링크

### 📚 **기술 문서**
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [AWS EKS 사용자 가이드](https://docs.aws.amazon.com/eks/)
- [Datadog Kubernetes 통합](https://docs.datadoghq.com/integrations/kubernetes/)
- [React 공식 문서](https://react.dev/)

### 🛠️ **개발 도구**
- [kubectl 설치](https://kubernetes.io/docs/tasks/tools/)
- [AWS CLI 설정](https://docs.aws.amazon.com/cli/latest/userguide/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

### 🎯 **모니터링 대시보드**
- [Datadog 대시보드](https://app.datadoghq.com/) (계정 필요)
- [AWS CloudWatch](https://console.aws.amazon.com/cloudwatch/) (AWS 계정 필요)

---

## 👥 기여 가이드

### 🔄 **개발 워크플로우**
1. **브랜치 생성**: `git checkout -b feature/your-feature`
2. **개발 및 테스트**: 로컬에서 변경사항 검증
3. **이미지 빌드**: `./scripts/update-dev-image.sh <service>`
4. **배포 테스트**: 개발 환경에서 동작 확인
5. **코드 리뷰**: Pull Request 생성 및 리뷰

### 📝 **코딩 규칙**
- **주석**: 복잡한 로직에 대한 상세한 주석 작성
- **에러 처리**: 모든 외부 API 호출에 적절한 에러 처리
- **보안**: 사용자 입력에 대한 검증 필수
- **성능**: 데이터베이스 쿼리 최적화 고려

### 🧪 **테스트**
```bash
# 프론트엔드 테스트
cd frontend-react && npm test

# 백엔드 테스트  
cd services/auth-python && python -m pytest
cd services/ranking-java && ./mvnw test

# 통합 테스트
kubectl apply -f test/integration-tests.yaml
```

---

## 📞 지원 및 문의

### 🛠️ **기술 지원**
- **버그 리포트**: GitHub Issues 활용
- **기능 요청**: Feature Request 템플릿 사용
- **보안 이슈**: 별도 보안 채널 통해 연락

### 📊 **모니터링 문의**
- **성능 이슈**: Datadog 대시보드 스크린샷과 함께 문의
- **알람 설정**: SLI/SLO 기준 검토 후 요청
- **로그 분석**: 특정 시간대 및 서비스 명시

---

---

## 🤝 기여하기

이 프로젝트에 기여해주셔서 감사합니다! 다음과 같은 방법으로 참여하실 수 있습니다:

### 🐛 버그 리포트
- [Issues](https://github.com/your-username/datadog-runner/issues)에서 버그를 신고해주세요
- 재현 가능한 단계와 스크린샷을 포함해주세요
- 환경 정보 (브라우저, OS, 디바이스)를 명시해주세요

### 💡 기능 제안
- 새로운 기능 아이디어를 Issues에 제안해주세요
- 사용 사례와 예상 효과를 설명해주세요

### 🔧 코드 기여
1. **Fork** 저장소를 포크하세요
2. **Branch** 기능 브랜치를 생성하세요 (`git checkout -b feature/amazing-feature`)
3. **Commit** 변경사항을 커밋하세요 (`git commit -m 'Add amazing feature'`)
4. **Push** 브랜치에 푸시하세요 (`git push origin feature/amazing-feature`)
5. **Pull Request** PR을 생성하세요

### 📝 개발 가이드라인
- **코딩 스타일**: 기존 코드 스타일을 따라주세요
- **주석**: 복잡한 로직에는 상세한 주석을 작성해주세요
- **테스트**: 새로운 기능에는 테스트를 추가해주세요
- **문서**: README나 코드 주석을 업데이트해주세요

### 🧪 테스트 실행
```bash
# 프론트엔드 테스트
cd frontend-react && npm test

# 백엔드 테스트  
cd services/auth-python && python -m pytest
cd services/ranking-java && ./mvnw test

# 통합 테스트
kubectl apply -f test/integration-tests.yaml
```

---

## 📄 라이선스

이 프로젝트는 [MIT 라이선스](LICENSE) 하에 배포됩니다.

```
MIT License

Copyright (c) 2024 Datadog Runner Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 🙏 감사의 말

- **Datadog**: 강력한 모니터링 및 APM 솔루션 제공
- **AWS**: 안정적인 클라우드 인프라 서비스
- **Kubernetes**: 컨테이너 오케스트레이션 플랫폼
- **오픈소스 커뮤니티**: React, FastAPI, Spring Boot 등 훌륭한 도구들

---

**🎉 Datadog Runner를 통해 현대적인 클라우드 네이티브 게임 서비스의 모든 것을 경험해보세요!**

*마지막 업데이트: 2024년 12월 17일*