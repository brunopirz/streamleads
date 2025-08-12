# 🚀 Guia de Instalação - StreamLeads

## Visão Geral

Este guia apresenta diferentes formas de instalar e executar o StreamLeads em diversas plataformas e ambientes.

## 📋 Índice

1. [Docker & Docker Compose](#-docker--docker-compose)
2. [Portainer](#-portainer)
3. [Vercel](#-vercel)
4. [Railway](#-railway)
5. [Heroku](#-heroku)
6. [DigitalOcean App Platform](#-digitalocean-app-platform)
7. [AWS (ECS/Fargate)](#-aws-ecsfargate)
8. [Google Cloud Run](#-google-cloud-run)
9. [Azure Container Instances](#-azure-container-instances)
10. [VPS/Servidor Dedicado](#-vpsservidor-dedicado)
11. [Kubernetes](#-kubernetes)
12. [Instalação Local](#-instalação-local)

---

## 🐳 Docker & Docker Compose

### Pré-requisitos
- Docker 20.10+
- Docker Compose 2.0+

### Instalação Rápida

```bash
# 1. Clonar repositório
git clone https://github.com/seu-usuario/streamleads.git
cd streamleads

# 2. Configurar ambiente
cp .env.example .env
# Editar .env conforme necessário

# 3. Iniciar serviços
docker-compose up -d

# 4. Verificar status
docker-compose ps
```

### Configuração Personalizada

**docker-compose.override.yml** (para desenvolvimento):
```yaml
version: '3.8'

services:
  api:
    volumes:
      - .:/app
    environment:
      - DEBUG=True
      - LOG_LEVEL=DEBUG
    ports:
      - "8000:8000"
  
  dashboard:
    volumes:
      - .:/app
    environment:
      - STREAMLIT_SERVER_RUN_ON_SAVE=true
    ports:
      - "8501:8501"
```

### Comandos Úteis

```bash
# Logs em tempo real
docker-compose logs -f

# Restart específico
docker-compose restart api

# Backup do banco
docker-compose exec db pg_dump -U postgres streamleads > backup.sql

# Executar migrações
docker-compose exec api alembic upgrade head

# Shell no container
docker-compose exec api bash
```

---

## 🎛️ Portainer

### 1. Instalar Portainer

```bash
# Criar volume
docker volume create portainer_data

# Executar Portainer
docker run -d -p 8000:8000 -p 9443:9443 \
  --name portainer --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

### 2. Deploy via Portainer

1. **Acesse**: https://localhost:9443
2. **Crie conta** de administrador
3. **Conecte** ao Docker local
4. **Vá em Stacks** > **Add Stack**
5. **Cole o docker-compose.yml**:

```yaml
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: streamleads
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres123
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - streamleads

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    networks:
      - streamleads

  api:
    image: seu-usuario/streamleads:latest
    environment:
      - DATABASE_URL=postgresql://postgres:postgres123@db:5432/streamleads
      - REDIS_URL=redis://redis:6379/0
    ports:
      - "8000:8000"
    depends_on:
      - db
      - redis
    networks:
      - streamleads

  dashboard:
    image: seu-usuario/streamleads:latest
    command: streamlit run dashboard/main.py --server.port=8501 --server.address=0.0.0.0
    environment:
      - API_BASE_URL=http://api:8000
    ports:
      - "8501:8501"
    depends_on:
      - api
    networks:
      - streamleads

volumes:
  postgres_data:
  redis_data:

networks:
  streamleads:
    driver: bridge
```

6. **Configure** variáveis de ambiente
7. **Deploy** a stack

### 3. Monitoramento no Portainer

- **Containers**: Status, logs, estatísticas
- **Images**: Gerenciar imagens Docker
- **Volumes**: Backup e restore
- **Networks**: Configuração de rede

---

## ▲ Vercel

> **Nota**: Vercel é ideal apenas para o frontend/dashboard. A API precisa de outro serviço.

### 1. Preparar Projeto

**vercel.json**:
```json
{
  "version": 2,
  "builds": [
    {
      "src": "dashboard/main.py",
      "use": "@vercel/python"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "dashboard/main.py"
    }
  ],
  "env": {
    "API_BASE_URL": "https://sua-api.railway.app"
  }
}
```

**requirements.txt** (para Vercel):
```txt
streamlit==1.28.0
requests==2.31.0
plotly==5.17.0
pandas==2.1.0
```

### 2. Deploy

```bash
# Instalar Vercel CLI
npm i -g vercel

# Login
vercel login

# Deploy
vercel --prod
```

### 3. Configurar Variáveis

```bash
# Via CLI
vercel env add API_BASE_URL

# Ou via dashboard Vercel
# Settings > Environment Variables
```

---

## 🚂 Railway

### 1. Deploy via GitHub

1. **Conecte** repositório no [Railway](https://railway.app)
2. **Selecione** o repositório StreamLeads
3. **Configure** variáveis de ambiente:

```bash
# Banco de dados (Railway PostgreSQL)
DATABASE_URL=${{Postgres.DATABASE_URL}}

# Redis (Railway Redis)
REDIS_URL=${{Redis.REDIS_URL}}

# Aplicação
SECRET_KEY=sua-chave-secreta
ENVIRONMENT=production
DEBUG=False

# Porta (Railway)
PORT=8000
```

### 2. railway.json

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "Dockerfile"
  },
  "deploy": {
    "startCommand": "uvicorn app.main:app --host 0.0.0.0 --port $PORT",
    "healthcheckPath": "/health",
    "healthcheckTimeout": 100,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

### 3. Serviços Separados

**API Service**:
- **Start Command**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
- **Health Check**: `/health`

**Dashboard Service**:
- **Start Command**: `streamlit run dashboard/main.py --server.port $PORT --server.address 0.0.0.0`
- **Environment**: `API_BASE_URL=https://api-service.railway.app`

**Worker Service**:
- **Start Command**: `celery -A app.worker worker --loglevel=info`

---

## 🟣 Heroku

### 1. Preparar Projeto

**Procfile**:
```
web: uvicorn app.main:app --host 0.0.0.0 --port $PORT
worker: celery -A app.worker worker --loglevel=info
beat: celery -A app.worker beat --loglevel=info
```

**runtime.txt**:
```
python-3.11.6
```

**app.json**:
```json
{
  "name": "StreamLeads",
  "description": "Sistema de Automação de Leads",
  "repository": "https://github.com/seu-usuario/streamleads",
  "keywords": ["python", "fastapi", "streamlit", "leads"],
  "addons": [
    "heroku-postgresql:mini",
    "heroku-redis:mini"
  ],
  "env": {
    "SECRET_KEY": {
      "description": "Chave secreta para JWT",
      "generator": "secret"
    },
    "ENVIRONMENT": {
      "value": "production"
    },
    "DEBUG": {
      "value": "False"
    }
  },
  "formation": {
    "web": {
      "quantity": 1,
      "size": "basic"
    },
    "worker": {
      "quantity": 1,
      "size": "basic"
    }
  }
}
```

### 2. Deploy

```bash
# Instalar Heroku CLI
# https://devcenter.heroku.com/articles/heroku-cli

# Login
heroku login

# Criar app
heroku create streamleads-app

# Adicionar addons
heroku addons:create heroku-postgresql:mini
heroku addons:create heroku-redis:mini

# Configurar variáveis
heroku config:set SECRET_KEY=sua-chave-secreta
heroku config:set ENVIRONMENT=production

# Deploy
git push heroku main

# Executar migrações
heroku run alembic upgrade head

# Escalar workers
heroku ps:scale worker=1 beat=1
```

---

## 🌊 DigitalOcean App Platform

### 1. app.yaml

```yaml
name: streamleads
services:
- name: api
  source_dir: /
  github:
    repo: seu-usuario/streamleads
    branch: main
  run_command: uvicorn app.main:app --host 0.0.0.0 --port $PORT
  environment_slug: python
  instance_count: 1
  instance_size_slug: basic-xxs
  http_port: 8000
  health_check:
    http_path: /health
  envs:
  - key: DATABASE_URL
    scope: RUN_TIME
    value: ${db.DATABASE_URL}
  - key: REDIS_URL
    scope: RUN_TIME
    value: ${redis.DATABASE_URL}
  - key: SECRET_KEY
    scope: RUN_TIME
    value: sua-chave-secreta
  - key: ENVIRONMENT
    scope: RUN_TIME
    value: production

- name: dashboard
  source_dir: /
  github:
    repo: seu-usuario/streamleads
    branch: main
  run_command: streamlit run dashboard/main.py --server.port $PORT --server.address 0.0.0.0
  environment_slug: python
  instance_count: 1
  instance_size_slug: basic-xxs
  http_port: 8501
  envs:
  - key: API_BASE_URL
    scope: RUN_TIME
    value: ${api.PUBLIC_URL}

- name: worker
  source_dir: /
  github:
    repo: seu-usuario/streamleads
    branch: main
  run_command: celery -A app.worker worker --loglevel=info
  environment_slug: python
  instance_count: 1
  instance_size_slug: basic-xxs
  envs:
  - key: DATABASE_URL
    scope: RUN_TIME
    value: ${db.DATABASE_URL}
  - key: REDIS_URL
    scope: RUN_TIME
    value: ${redis.DATABASE_URL}

databases:
- name: db
  engine: PG
  version: "15"
  size: basic-xs
  num_nodes: 1

- name: redis
  engine: REDIS
  version: "7"
  size: basic-xs
  num_nodes: 1
```

### 2. Deploy

```bash
# Via CLI
doctl apps create app.yaml

# Ou via interface web
# https://cloud.digitalocean.com/apps
```

---

## ☁️ AWS (ECS/Fargate)

### 1. Dockerfile Multi-stage

```dockerfile
# Já existe no projeto
# Usar target: production
```

### 2. Task Definition

**task-definition.json**:
```json
{
  "family": "streamleads",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "api",
      "image": "ACCOUNT.dkr.ecr.REGION.amazonaws.com/streamleads:latest",
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "DATABASE_URL",
          "value": "postgresql://user:pass@rds-endpoint:5432/streamleads"
        },
        {
          "name": "REDIS_URL",
          "value": "redis://elasticache-endpoint:6379/0"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/streamleads",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### 3. Deploy Script

```bash
#!/bin/bash

# Build e push para ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.us-east-1.amazonaws.com

docker build -t streamleads .
docker tag streamleads:latest ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/streamleads:latest
docker push ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/streamleads:latest

# Atualizar serviço
aws ecs update-service --cluster streamleads-cluster --service streamleads-service --force-new-deployment
```

---

## 🏃 Google Cloud Run

### 1. cloudbuild.yaml

```yaml
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', 'gcr.io/$PROJECT_ID/streamleads', '.']
- name: 'gcr.io/cloud-builders/docker'
  args: ['push', 'gcr.io/$PROJECT_ID/streamleads']
- name: 'gcr.io/cloud-builders/gcloud'
  args:
  - 'run'
  - 'deploy'
  - 'streamleads-api'
  - '--image'
  - 'gcr.io/$PROJECT_ID/streamleads'
  - '--region'
  - 'us-central1'
  - '--platform'
  - 'managed'
  - '--allow-unauthenticated'
  - '--set-env-vars'
  - 'DATABASE_URL=postgresql://user:pass@/streamleads?host=/cloudsql/PROJECT:REGION:INSTANCE'
```

### 2. Deploy

```bash
# Via CLI
gcloud run deploy streamleads-api \
  --image gcr.io/PROJECT_ID/streamleads \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars DATABASE_URL=postgresql://...

# Via Cloud Build
gcloud builds submit --config cloudbuild.yaml
```

---

## 🔷 Azure Container Instances

### 1. azure-deploy.yaml

```yaml
apiVersion: 2019-12-01
location: eastus
name: streamleads
properties:
  containers:
  - name: api
    properties:
      image: streamleads:latest
      resources:
        requests:
          cpu: 1
          memoryInGb: 1.5
      ports:
      - port: 8000
      environmentVariables:
      - name: DATABASE_URL
        value: postgresql://...
      - name: REDIS_URL
        value: redis://...
  - name: dashboard
    properties:
      image: streamleads:latest
      command: ["streamlit", "run", "dashboard/main.py", "--server.port=8501", "--server.address=0.0.0.0"]
      resources:
        requests:
          cpu: 0.5
          memoryInGb: 1
      ports:
      - port: 8501
  osType: Linux
  ipAddress:
    type: Public
    ports:
    - protocol: tcp
      port: 8000
    - protocol: tcp
      port: 8501
  restartPolicy: Always
tags:
  environment: production
  project: streamleads
type: Microsoft.ContainerInstance/containerGroups
```

### 2. Deploy

```bash
# Via Azure CLI
az container create --resource-group streamleads-rg --file azure-deploy.yaml

# Via ARM Template
az deployment group create --resource-group streamleads-rg --template-file azure-deploy.yaml
```

---

## 🖥️ VPS/Servidor Dedicado

### 1. Preparação do Servidor

```bash
# Ubuntu 22.04 LTS
sudo apt update && sudo apt upgrade -y

# Instalar dependências
sudo apt install -y curl wget git nginx certbot python3-certbot-nginx

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Reiniciar sessão
logout
```

### 2. Configurar Nginx

**/etc/nginx/sites-available/streamleads**:
```nginx
server {
    listen 80;
    server_name api.streamleads.com;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

server {
    listen 80;
    server_name dashboard.streamleads.com;
    
    location / {
        proxy_pass http://localhost:8501;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support for Streamlit
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

```bash
# Ativar site
sudo ln -s /etc/nginx/sites-available/streamleads /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# SSL com Let's Encrypt
sudo certbot --nginx -d api.streamleads.com -d dashboard.streamleads.com
```

### 3. Deploy da Aplicação

```bash
# Clonar projeto
git clone https://github.com/seu-usuario/streamleads.git /opt/streamleads
cd /opt/streamleads

# Configurar ambiente
cp .env.example .env
nano .env

# Iniciar serviços
docker-compose -f docker-compose.prod.yml up -d

# Configurar auto-start
sudo systemctl enable docker
```

---

## ☸️ Kubernetes

### 1. Manifests

**k8s/namespace.yaml**:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: streamleads
```

**k8s/configmap.yaml**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: streamleads-config
  namespace: streamleads
data:
  ENVIRONMENT: "production"
  DEBUG: "False"
  API_HOST: "0.0.0.0"
  API_PORT: "8000"
```

**k8s/secret.yaml**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: streamleads-secrets
  namespace: streamleads
type: Opaque
data:
  SECRET_KEY: <base64-encoded-secret>
  DATABASE_URL: <base64-encoded-db-url>
  REDIS_URL: <base64-encoded-redis-url>
```

**k8s/deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: streamleads-api
  namespace: streamleads
spec:
  replicas: 3
  selector:
    matchLabels:
      app: streamleads-api
  template:
    metadata:
      labels:
        app: streamleads-api
    spec:
      containers:
      - name: api
        image: streamleads:latest
        ports:
        - containerPort: 8000
        envFrom:
        - configMapRef:
            name: streamleads-config
        - secretRef:
            name: streamleads-secrets
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
```

**k8s/service.yaml**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: streamleads-api-service
  namespace: streamleads
spec:
  selector:
    app: streamleads-api
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8000
  type: ClusterIP
```

**k8s/ingress.yaml**:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: streamleads-ingress
  namespace: streamleads
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - api.streamleads.com
    - dashboard.streamleads.com
    secretName: streamleads-tls
  rules:
  - host: api.streamleads.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: streamleads-api-service
            port:
              number: 80
  - host: dashboard.streamleads.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: streamleads-dashboard-service
            port:
              number: 80
```

### 2. Deploy

```bash
# Aplicar manifests
kubectl apply -f k8s/

# Verificar status
kubectl get pods -n streamleads
kubectl get services -n streamleads
kubectl get ingress -n streamleads

# Logs
kubectl logs -f deployment/streamleads-api -n streamleads
```

---

## 💻 Instalação Local

### 1. Pré-requisitos

- Python 3.11+
- PostgreSQL 15+
- Redis 7+
- Node.js 18+ (opcional, para ferramentas)

### 2. Instalação

```bash
# 1. Clonar repositório
git clone https://github.com/seu-usuario/streamleads.git
cd streamleads

# 2. Criar ambiente virtual
python -m venv venv

# 3. Ativar ambiente virtual
# Windows
venv\Scripts\activate
# Linux/Mac
source venv/bin/activate

# 4. Instalar dependências
pip install -r requirements.txt
pip install -r requirements-dev.txt

# 5. Configurar banco PostgreSQL
# Criar banco: streamleads_dev
# Usuário: postgres
# Senha: postgres123

# 6. Configurar ambiente
cp .env.example .env
# Editar .env com configurações locais

# 7. Executar migrações
alembic upgrade head

# 8. Popular banco com dados de teste
python scripts/init_db.py

# 9. Iniciar API
uvicorn app.main:app --reload

# 10. Iniciar Dashboard (novo terminal)
streamlit run dashboard/main.py

# 11. Iniciar Worker (novo terminal)
celery -A app.worker worker --loglevel=info
```

### 3. Verificação

- **API**: http://localhost:8000
- **Docs**: http://localhost:8000/docs
- **Dashboard**: http://localhost:8501
- **Health**: http://localhost:8000/health

---

## 🔧 Troubleshooting

### Problemas Comuns

**1. Porta já em uso**
```bash
# Verificar processo
lsof -i :8000
# Matar processo
kill -9 PID
```

**2. Banco não conecta**
```bash
# Verificar status PostgreSQL
sudo systemctl status postgresql
# Reiniciar
sudo systemctl restart postgresql
```

**3. Redis não conecta**
```bash
# Verificar Redis
redis-cli ping
# Deve retornar PONG
```

**4. Dependências**
```bash
# Limpar cache pip
pip cache purge
# Reinstalar
pip install -r requirements.txt --force-reinstall
```

### Logs e Debug

```bash
# Logs da aplicação
tail -f logs/app.log

# Logs do Docker
docker-compose logs -f api

# Debug mode
export DEBUG=True
export LOG_LEVEL=DEBUG
```

---

## 📊 Comparação de Plataformas

| Plataforma | Facilidade | Custo | Escalabilidade | Controle |
|------------|------------|-------|----------------|----------|
| Docker Local | ⭐⭐⭐⭐⭐ | 💰 | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| Railway | ⭐⭐⭐⭐⭐ | 💰💰 | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Vercel | ⭐⭐⭐⭐ | 💰💰 | ⭐⭐⭐ | ⭐⭐ |
| Heroku | ⭐⭐⭐⭐ | 💰💰💰 | ⭐⭐⭐ | ⭐⭐ |
| DigitalOcean | ⭐⭐⭐⭐ | 💰💰 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| AWS | ⭐⭐ | 💰💰💰 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| VPS | ⭐⭐ | 💰 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Kubernetes | ⭐ | 💰💰💰 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

### Recomendações

- **Desenvolvimento**: Docker Local
- **MVP/Teste**: Railway ou Vercel
- **Produção Pequena**: DigitalOcean App Platform
- **Produção Média**: VPS com Docker
- **Produção Grande**: AWS/GCP com Kubernetes

---

**Documentação mantida por**: Equipe de Desenvolvimento StreamLeads  
**Última atualização**: Dezembro 2024  
**Versão**: 1.0.0