# redis-cluster-helm

[![Helm](https://img.shields.io/badge/Helm-3.2+-blue)](https://helm.sh)
[![License](https://img.shields.io/badge/License-Apache%202.0-green)](LICENSE)

Bitnami `redis-cluster` 차트가 유료화됨에 따라 공식 Redis 이미지를 사용하는 대체 Helm Chart입니다.
외부 라이브러리 의존성 없이 동일한 클러스터 구성을 제공합니다.

> **Redis 버전** — [`Chart.yaml`](./Chart.yaml)의 `appVersion` 참고.
> 버전 업데이트 시 `Chart.yaml`과 `values.yaml` 두 곳만 수정하면 됩니다.

## 특징

- **공식 이미지** — Docker Hub `redis` 공식 이미지 사용 (Bitnami 구독 불필요)
- **IP 기반 클러스터** — Kubernetes Downward API로 Pod IP 주입, CNI(AWS VPC CNI, Calico, Cilium 등)에 무관하게 동작
- **멱등 초기화** — Helm post-install/post-upgrade Job으로 클러스터 자동 구성, 이미 구성된 경우 스킵
- **비밀번호 보존** — `helm upgrade` 시 기존 Secret lookup으로 비밀번호 재생성 방지
- **Prometheus 지원** — redis_exporter 사이드카 및 ServiceMonitor 옵션 제공
- **의존성 없음** — bitnami/common 라이브러리 불필요

## 기본 클러스터 구성

```
마스터 3개 + 레플리카 3개 = 총 6 Pod
슬롯: 16,384개 (마스터당 약 5,461개)
```

## 요구 사항

- Kubernetes 1.21+
- Helm 3.2+
- PersistentVolume provisioner (`persistence.enabled=true` 시)

## 설치

### Helm Repository (권장)

```bash
helm repo add redis-cluster https://binarynum01.github.io/redis-cluster-helm
helm repo update

# 기본 설치 (비밀번호 자동 생성)
helm install my-redis redis-cluster/redis-cluster -n redis --create-namespace

# 특정 버전 설치
helm install my-redis redis-cluster/redis-cluster \
  --version 1.0.0 \
  -n redis --create-namespace

# 비밀번호 직접 지정
helm install my-redis redis-cluster/redis-cluster \
  --set auth.password=mypassword \
  -n redis --create-namespace

# values 파일 사용
helm install my-redis redis-cluster/redis-cluster \
  -f my-values.yaml \
  -n redis --create-namespace
```

### 소스에서 설치

```bash
git clone https://github.com/binarynum01/redis-cluster-helm.git
helm install my-redis ./redis-cluster-helm -n redis --create-namespace
```

## 업그레이드

```bash
helm repo update
helm upgrade my-redis redis-cluster/redis-cluster -n redis
```

> 업그레이드 시 클러스터가 이미 구성되어 있으면 init Job이 자동으로 스킵됩니다.

## 삭제

```bash
helm uninstall my-redis -n redis

# PVC까지 함께 삭제
kubectl delete pvc -l app.kubernetes.io/instance=my-redis -n redis
```

## 클러스터 상태 확인

```bash
# Pod 상태
kubectl get pods -l app.kubernetes.io/instance=my-redis -n redis

# init Job 로그
kubectl logs -l job-name=my-redis-redis-cluster-init -n redis

# 비밀번호 조회
REDIS_PASSWORD=$(
  kubectl get secret my-redis-redis-cluster -n redis \
    -o jsonpath='{.data.redis-password}' | base64 -d
)

# 클러스터 정보
kubectl exec -it my-redis-redis-cluster-0 -n redis -- \
  redis-cli -a "$REDIS_PASSWORD" CLUSTER INFO

# 노드 목록
kubectl exec -it my-redis-redis-cluster-0 -n redis -- \
  redis-cli -a "$REDIS_PASSWORD" CLUSTER NODES
```

## 주요 설정값

### 클러스터

```yaml
cluster:
  nodes: 6       # 총 노드 수. 반드시 masters × (1 + replicas) 여야 함
  replicas: 1    # 마스터당 레플리카 수 (최소 1 권장)
  init: true     # 설치/업그레이드 시 클러스터 자동 초기화
```

### 인증

```yaml
auth:
  enabled: true
  password: ""                        # 비어 있으면 16자리 랜덤 생성
  existingSecret: ""                  # 기존 Secret 이름 (지정 시 password 무시)
  existingSecretPasswordKey: "redis-password"
```

### 퍼시스턴스

```yaml
persistence:
  enabled: true
  storageClass: ""   # 빈 값 = 클러스터 기본 StorageClass
  size: 8Gi
  accessMode: ReadWriteOnce
```

### Redis 설정 커스터마이징

```yaml
redis:
  port: 6379
  config:
    cluster-node-timeout: "5000"
    maxmemory: "512mb"
    maxmemory-policy: "allkeys-lru"
  extraConfig: |
    lazyfree-lazy-eviction yes
    lazyfree-lazy-expire yes
```

### Prometheus 메트릭

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true   # Prometheus Operator 사용 환경
```

### 스케줄링

```yaml
podAntiAffinityPreset: soft   # soft | hard | none
nodeSelector: {}
tolerations: []
topologySpreadConstraints: []
```

## Bitnami 차트와 비교

| 항목 | Bitnami redis-cluster | 이 차트 |
|------|----------------------|---------|
| 이미지 | bitnami/redis-cluster (유료) | redis (공식, 무료) |
| 외부 의존성 | bitnami/common 라이브러리 | 없음 |
| 클러스터 초기화 | pod-0 내부 스크립트 | 별도 Kubernetes Job |
| 클러스터 앤드포인트 | IP 기반 | IP 기반 (Downward API, CNI-agnostic) |
| 업그레이드 시 비밀번호 | 재생성 위험 | Secret lookup으로 보존 |
| Prometheus 지원 | bitnami/redis-exporter | oliver006/redis_exporter |

## 트러블슈팅

### Pod가 Ready 상태가 되지 않을 때

Readiness probe는 PING 응답만 확인합니다. 클러스터 초기화(init Job)와 무관하게 Redis 프로세스가 실행되면 Ready가 됩니다.

```bash
# Pod 이벤트 확인
kubectl describe pod my-redis-redis-cluster-0 -n redis

# Redis 로그 확인
kubectl logs my-redis-redis-cluster-0 -n redis

# init Job 상태 확인
kubectl get job my-redis-redis-cluster-init -n redis
kubectl logs -l job-name=my-redis-redis-cluster-init -n redis
```

### 클러스터 초기화 실패 시 수동 재시도

```bash
# Job 삭제 후 helm upgrade로 재실행
kubectl delete job my-redis-redis-cluster-init -n redis
helm upgrade my-redis redis-cluster/redis-cluster -n redis
```

### 노드 수 변경 (스케일 아웃)

`cluster.nodes` 값을 늘린 후 `helm upgrade`를 실행하면 init Job이 새 노드를 클러스터에 추가합니다.
단, 클러스터가 이미 `ok` 상태인 경우 Job이 스킵되므로 수동으로 `redis-cli --cluster add-node`를 실행해야 합니다.

## 라이선스

Apache 2.0
