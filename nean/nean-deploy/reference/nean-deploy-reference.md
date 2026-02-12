# NEAN Deploy Reference

Deployment configurations for Docker, AWS, and Kubernetes.

---

## Docker Deployment

### API Dockerfile

```dockerfile
# docker/Dockerfile.api
FROM node:22-alpine AS base

FROM base AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM base AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npx nx build api --prod

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production

# Create non-root user
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nestjs
USER nestjs

COPY --from=deps --chown=nestjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nestjs:nodejs /app/dist/apps/api ./dist

EXPOSE 3000
CMD ["node", "dist/main.js"]
```

### Web Dockerfile

```dockerfile
# docker/Dockerfile.web
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npx nx build web --prod

FROM nginx:alpine AS runner
# Copy custom nginx config
COPY docker/nginx.conf /etc/nginx/nginx.conf
# Copy built Angular app
COPY --from=builder /app/dist/apps/web/browser /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Nginx Configuration

```nginx
# docker/nginx.conf
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    server {
        listen 80;
        server_name _;
        root /usr/share/nginx/html;
        index index.html;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # API proxy
        location /api {
            proxy_pass http://api:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }

        # Angular routing - serve index.html for all routes
        location / {
            try_files $uri $uri/ /index.html;
        }

        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
}
```

### Docker Compose

```yaml
# docker/docker-compose.yml
version: '3.8'

services:
  api:
    build:
      context: ..
      dockerfile: docker/Dockerfile.api
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_HOST=db
      - DATABASE_PORT=5432
      - DATABASE_USERNAME=postgres
      - DATABASE_PASSWORD=${DB_PASSWORD}
      - DATABASE_NAME=myapp
      - JWT_SECRET=${JWT_SECRET}
      - JWT_EXPIRES_IN=15m
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped

  web:
    build:
      context: ..
      dockerfile: docker/Dockerfile.web
    ports:
      - "80:80"
    depends_on:
      - api
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_DB=myapp
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  postgres_data:
```

### Production Overrides

```yaml
# docker/docker-compose.prod.yml
version: '3.8'

services:
  api:
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  web:
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '0.5'
          memory: 128M
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  db:
    volumes:
      - /data/postgres:/var/lib/postgresql/data
```

---

## AWS Deployment

### ECS Task Definition

```json
{
  "family": "myapp-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "api",
      "image": "ACCOUNT.dkr.ecr.REGION.amazonaws.com/myapp-api:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "NODE_ENV", "value": "production"},
        {"name": "DATABASE_HOST", "value": "myapp-db.cluster-xxx.REGION.rds.amazonaws.com"},
        {"name": "DATABASE_PORT", "value": "5432"},
        {"name": "DATABASE_NAME", "value": "myapp"}
      ],
      "secrets": [
        {
          "name": "DATABASE_USERNAME",
          "valueFrom": "arn:aws:secretsmanager:REGION:ACCOUNT:secret:myapp/db:username::"
        },
        {
          "name": "DATABASE_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:REGION:ACCOUNT:secret:myapp/db:password::"
        },
        {
          "name": "JWT_SECRET",
          "valueFrom": "arn:aws:secretsmanager:REGION:ACCOUNT:secret:myapp/jwt:secret::"
        }
      ],
      "healthCheck": {
        "command": ["CMD-SHELL", "wget -qO- http://localhost:3000/api/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/myapp-api",
          "awslogs-region": "REGION",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### Terraform Configuration

```hcl
# infrastructure/terraform/main.tf

provider "aws" {
  region = var.aws_region
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.app_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = var.environment != "prod"
}

# RDS
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.app_name}-db"

  engine               = "postgres"
  engine_version       = "16"
  family               = "postgres16"
  major_engine_version = "16"
  instance_class       = var.environment == "prod" ? "db.t3.medium" : "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = var.app_name
  username = var.db_username
  port     = 5432

  vpc_security_group_ids = [module.security_group_rds.security_group_id]
  subnet_ids             = module.vpc.private_subnets

  backup_retention_period = var.environment == "prod" ? 7 : 1
  deletion_protection     = var.environment == "prod"
}

# ECS Cluster
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.0"

  cluster_name = "${var.app_name}-cluster"

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }
}

# ALB
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name    = "${var.app_name}-alb"
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
    all_https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}
```

### Deploy Script

```bash
#!/bin/bash
# infrastructure/scripts/deploy.sh

set -e

ENVIRONMENT=${1:-staging}
AWS_REGION=${AWS_REGION:-us-east-1}
ECR_REPO="myapp"

echo "Deploying to $ENVIRONMENT..."

# Build and push images
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

docker build -t $ECR_REPO-api -f docker/Dockerfile.api .
docker tag $ECR_REPO-api:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO-api:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO-api:latest

docker build -t $ECR_REPO-web -f docker/Dockerfile.web .
docker tag $ECR_REPO-web:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO-web:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO-web:latest

# Update ECS services
aws ecs update-service --cluster myapp-cluster --service myapp-api --force-new-deployment
aws ecs update-service --cluster myapp-cluster --service myapp-web --force-new-deployment

echo "Deployment initiated. Monitor in AWS Console."
```

---

## Kubernetes Deployment

### Helm Chart Structure

```
k8s/helm/myapp/
├── Chart.yaml
├── values.yaml
├── values.prod.yaml
└── templates/
    ├── _helpers.tpl
    ├── api-deployment.yaml
    ├── api-service.yaml
    ├── web-deployment.yaml
    ├── web-service.yaml
    ├── ingress.yaml
    ├── configmap.yaml
    ├── secrets.yaml
    └── hpa.yaml
```

### Chart.yaml

```yaml
# k8s/helm/myapp/Chart.yaml
apiVersion: v2
name: myapp
description: NEAN Application
type: application
version: 0.1.0
appVersion: "1.0.0"
```

### Values

```yaml
# k8s/helm/myapp/values.yaml
replicaCount: 1

api:
  image:
    repository: myapp-api
    tag: latest
    pullPolicy: IfNotPresent
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
  env:
    NODE_ENV: production
    DATABASE_PORT: "5432"
    JWT_EXPIRES_IN: "15m"

web:
  image:
    repository: myapp-web
    tag: latest
    pullPolicy: IfNotPresent
  resources:
    limits:
      cpu: 200m
      memory: 128Mi
    requests:
      cpu: 100m
      memory: 64Mi

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: myapp.local
      paths:
        - path: /api
          pathType: Prefix
          service: api
        - path: /
          pathType: Prefix
          service: web
  tls: []

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80
```

### Production Values

```yaml
# k8s/helm/myapp/values.prod.yaml
replicaCount: 3

api:
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi

web:
  resources:
    limits:
      cpu: 500m
      memory: 256Mi
    requests:
      cpu: 200m
      memory: 128Mi

ingress:
  hosts:
    - host: myapp.example.com
      paths:
        - path: /api
          pathType: Prefix
          service: api
        - path: /
          pathType: Prefix
          service: web
  tls:
    - secretName: myapp-tls
      hosts:
        - myapp.example.com

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
```

### API Deployment

```yaml
# k8s/helm/myapp/templates/api-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "myapp.fullname" . }}-api
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
    app.kubernetes.io/component: api
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "myapp.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: api
  template:
    metadata:
      labels:
        {{- include "myapp.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: api
    spec:
      containers:
        - name: api
          image: "{{ .Values.api.image.repository }}:{{ .Values.api.image.tag }}"
          imagePullPolicy: {{ .Values.api.image.pullPolicy }}
          ports:
            - name: http
              containerPort: 3000
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /api/health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /api/health/ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            {{- toYaml .Values.api.resources | nindent 12 }}
          envFrom:
            - configMapRef:
                name: {{ include "myapp.fullname" . }}-config
            - secretRef:
                name: {{ include "myapp.fullname" . }}-secrets
```

---

## Health Check Endpoints

```typescript
// apps/api/src/modules/health/health.controller.ts
import { Controller, Get } from '@nestjs/common';
import { HealthCheck, HealthCheckService, TypeOrmHealthIndicator } from '@nestjs/terminus';

@Controller('health')
export class HealthController {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
  ) {}

  @Get()
  @HealthCheck()
  check() {
    return this.health.check([]);
  }

  @Get('ready')
  @HealthCheck()
  ready() {
    return this.health.check([
      () => this.db.pingCheck('database'),
    ]);
  }
}
```

---

## Environment Variables

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `NODE_ENV` | Yes | Environment | `production` |
| `DATABASE_HOST` | Yes | DB hostname | `db` or RDS endpoint |
| `DATABASE_PORT` | Yes | DB port | `5432` |
| `DATABASE_USERNAME` | Yes | DB username | `myapp` |
| `DATABASE_PASSWORD` | Yes | DB password | (from secrets) |
| `DATABASE_NAME` | Yes | DB name | `myapp` |
| `JWT_SECRET` | Yes | JWT signing key | (from secrets, 64+ chars) |
| `JWT_EXPIRES_IN` | Yes | Token expiry | `15m` |
| `CORS_ORIGINS` | Yes | Allowed origins | `https://myapp.com` |
| `API_PORT` | No | API port | `3000` |
| `LOG_LEVEL` | No | Log verbosity | `info` |

---

## Deployment Commands

```bash
# Docker
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml up -d
docker compose -f docker/docker-compose.yml -f docker/docker-compose.prod.yml up -d

# Kubernetes
helm install myapp k8s/helm/myapp
helm upgrade myapp k8s/helm/myapp -f k8s/helm/myapp/values.prod.yaml
helm rollback myapp 1

# AWS
./infrastructure/scripts/deploy.sh staging
./infrastructure/scripts/deploy.sh prod
```
