# 🚀 Deploy e Configuração em Produção - StreamLeads

## Visão Geral

Este guia fornece instruções detalhadas para deploy do StreamLeads em ambiente de produção, incluindo configurações de segurança, monitoramento e melhores práticas.

## 🏗️ Arquitetura de Produção

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Balancer │    │     Traefik     │    │   CloudFlare    │
│    (Nginx)      │◄──►│  (Proxy/SSL)    │◄──►│     (CDN)       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
          │                       │
          ▼                       ▼
┌─────────────────┐    ┌─────────────────┐
│   StreamLeads   │    │   StreamLeads   │
│   API (Node 1)  │    │   API (Node 2)  │
└─────────────────┘    └─────────────────┘
          │                       │
          └───────────┬───────────┘
                      ▼
          ┌─────────────────┐
          │   PostgreSQL    │
          │   (Primary)     │
          └─────────────────┘
                      │
                      ▼
          ┌─────────────────┐
          │   PostgreSQL    │
          │   (Replica)     │
          └─────────────────┘
```

## 🐳 Deploy com Docker

### 1. Configuração do Docker Compose para Produção

**docker-compose.prod.yml**:
```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v2.10
    container_name: streamleads-traefik
    restart: unless-stopped
    command:
      - --api.dashboard=true
      - --api.insecure=false
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.letsencrypt.acme.tlschallenge=true
      - --certificatesresolvers.letsencrypt.acme.email=${ACME_EMAIL}
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
      - --log.level=INFO
      - --accesslog=true
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    environment:
      - TRAEFIK_API_DASHBOARD=true
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`traefik.${DOMAIN}`)"
      - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"
      - "traefik.http.routers.traefik.service=api@internal"

  db:
    image: postgres:15-alpine
    container_name: streamleads-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
    ports:
      - "127.0.0.1:5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 30s
      timeout: 10s
      retries: 3
    command: >
      postgres
      -c shared_preload_libraries=pg_stat_statements
      -c pg_stat_statements.track=all
      -c max_connections=200
      -c shared_buffers=256MB
      -c effective_cache_size=1GB
      -c work_mem=4MB
      -c maintenance_work_mem=64MB

  redis:
    image: redis:7-alpine
    container_name: streamleads-redis
    restart: unless-stopped
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    ports:
      - "127.0.0.1:6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

  api:
    build:
      context: .
      dockerfile: Dockerfile.prod
    container_name: streamleads-api
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      - ENV=production
      - DB_HOST=db
      - DB_PORT=5432
      - DB_NAME=${DB_NAME}
      - DB_USER=${DB_USER}
      - DB_PASSWORD=${DB_PASSWORD}
      - REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379/0
      - SECRET_KEY=${SECRET_KEY}
      - API_HOST=0.0.0.0
      - API_PORT=8000
      - DEBUG=false
      - LOG_LEVEL=INFO
    volumes:
      - ./logs:/app/logs
      - ./uploads:/app/uploads
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`api.${DOMAIN}`)"
      - "traefik.http.routers.api.tls.certresolver=letsencrypt"
      - "traefik.http.services.api.loadbalancer.server.port=8000"
      - "traefik.http.routers.api.middlewares=api-ratelimit"
      - "traefik.http.middlewares.api-ratelimit.ratelimit.burst=100"
      - "traefik.http.middlewares.api-ratelimit.ratelimit.average=50"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  streamlit:
    build:
      context: .
      dockerfile: Dockerfile.streamlit
    container_name: streamleads-dashboard
    restart: unless-stopped
    depends_on:
      api:
        condition: service_healthy
    environment:
      - API_BASE_URL=http://api:8000
      - STREAMLIT_SERVER_PORT=8501
      - STREAMLIT_SERVER_ADDRESS=0.0.0.0
      - STREAMLIT_BROWSER_GATHER_USAGE_STATS=false
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`dashboard.${DOMAIN}`)"
      - "traefik.http.routers.dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.services.dashboard.loadbalancer.server.port=8501"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8501/_stcore/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  backup:
    image: postgres:15-alpine
    container_name: streamleads-backup
    restart: "no"
    depends_on:
      - db
    environment:
      PGPASSWORD: ${DB_PASSWORD}
    volumes:
      - ./backups:/backups
      - ./scripts/backup.sh:/backup.sh
    command: ["/backup.sh"]
    profiles: ["backup"]

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local

networks:
  default:
    name: streamleads-network
```

### 2. Dockerfile Otimizado para Produção

**Dockerfile.prod**:
```dockerfile
# Multi-stage build para otimização
FROM python:3.11-slim as builder

# Instalar dependências de build
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Criar ambiente virtual
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Instalar dependências Python
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Estágio de produção
FROM python:3.11-slim

# Criar usuário não-root
RUN groupadd -r streamleads && useradd -r -g streamleads streamleads

# Instalar dependências de runtime
RUN apt-get update && apt-get install -y \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copiar ambiente virtual
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Configurar diretório de trabalho
WORKDIR /app

# Copiar código da aplicação
COPY --chown=streamleads:streamleads . .

# Criar diretórios necessários
RUN mkdir -p /app/logs /app/uploads && \
    chown -R streamleads:streamleads /app

# Mudar para usuário não-root
USER streamleads

# Expor porta
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Comando de inicialização
CMD ["gunicorn", "app.main:app", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "-b", "0.0.0.0:8000", "--access-logfile", "-", "--error-logfile", "-", "--log-level", "info"]
```

### 3. Configuração de Ambiente de Produção

**.env.prod**:
```bash
# Ambiente
ENV=production
DEBUG=false
LOG_LEVEL=INFO

# Domínio
DOMAIN=streamleads.com
ACME_EMAIL=admin@streamleads.com

# Banco de Dados
DB_HOST=db
DB_PORT=5432
DB_NAME=streamleads_prod
DB_USER=streamleads_user
DB_PASSWORD=sua_senha_super_segura_aqui

# Redis
REDIS_URL=redis://:sua_senha_redis@redis:6379/0
REDIS_PASSWORD=sua_senha_redis

# API
API_HOST=0.0.0.0
API_PORT=8000
SECRET_KEY=sua_chave_secreta_de_256_bits_aqui
TOKEN_EXPIRE_HOURS=24

# Integrações
N8N_WEBHOOK_URL=https://n8n.streamleads.com/webhook
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
WHATSAPP_API_URL=https://api.whatsapp.com/send
WHATSAPP_TOKEN=seu_token_whatsapp

# Email
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=noreply@streamleads.com
SMTP_PASSWORD=sua_senha_app_gmail

# Scoring
SCORE_CAMPOS_OBRIGATORIOS=10
SCORE_INTERESSE_ALTO_TICKET=15
SCORE_REGIAO_ATENDIDA=5
SCORE_THRESHOLD_QUENTE=25
SCORE_THRESHOLD_MORNO=15

# Monitoramento
SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id
NEW_RELIC_LICENSE_KEY=your_new_relic_license_key
```

## 🔒 Configurações de Segurança

### 1. SSL/TLS com Let's Encrypt

**Configuração automática via Traefik**:
```yaml
# Já incluído no docker-compose.prod.yml
certificatesresolvers:
  letsencrypt:
    acme:
      tlschallenge: true
      email: admin@streamleads.com
      storage: /letsencrypt/acme.json
```

### 2. Firewall e Segurança de Rede

**UFW (Ubuntu Firewall)**:
```bash
# Configurar firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Verificar status
sudo ufw status verbose
```

### 3. Configuração de Secrets

**Docker Secrets** (para Docker Swarm):
```yaml
secrets:
  db_password:
    external: true
  secret_key:
    external: true
  smtp_password:
    external: true

services:
  api:
    secrets:
      - db_password
      - secret_key
      - smtp_password
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password
      - SECRET_KEY_FILE=/run/secrets/secret_key
```

### 4. Rate Limiting e DDoS Protection

**Configuração no Traefik**:
```yaml
labels:
  - "traefik.http.middlewares.api-ratelimit.ratelimit.burst=100"
  - "traefik.http.middlewares.api-ratelimit.ratelimit.average=50"
  - "traefik.http.middlewares.api-auth.basicauth.users=admin:$$2y$$10$$..."
```

## 📊 Monitoramento e Observabilidade

### 1. Logging Estruturado

**Configuração do Loguru**:
```python
# app/config.py
import sys
from loguru import logger

# Configurar logging para produção
if settings.ENV == "production":
    logger.remove()  # Remove handler padrão
    
    # Log para arquivo com rotação
    logger.add(
        "/app/logs/streamleads.log",
        rotation="100 MB",
        retention="30 days",
        compression="gzip",
        format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {name}:{function}:{line} | {message}",
        level="INFO"
    )
    
    # Log para stdout (Docker)
    logger.add(
        sys.stdout,
        format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {name}:{function}:{line} | {message}",
        level="INFO"
    )
    
    # Log de erros separado
    logger.add(
        "/app/logs/errors.log",
        rotation="50 MB",
        retention="60 days",
        compression="gzip",
        level="ERROR"
    )
```

### 2. Métricas com Prometheus

**docker-compose.monitoring.yml**:
```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: streamleads-prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'

  grafana:
    image: grafana/grafana:latest
    container_name: streamleads-grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
    volumes:
      - grafana_data:/var/lib/grafana
      - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources

  node-exporter:
    image: prom/node-exporter:latest
    container_name: streamleads-node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

volumes:
  prometheus_data:
  grafana_data:
```

### 3. Health Checks e Alertas

**Script de Health Check**:
```bash
#!/bin/bash
# scripts/health-check.sh

API_URL="https://api.streamleads.com/health"
SLACK_WEBHOOK="$SLACK_WEBHOOK_URL"

# Verificar API
if ! curl -f -s "$API_URL" > /dev/null; then
    curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"🚨 ALERTA: API StreamLeads está fora do ar!"}' \
        "$SLACK_WEBHOOK"
    exit 1
fi

# Verificar banco de dados
if ! docker exec streamleads-db pg_isready -U streamleads_user -d streamleads_prod; then
    curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"🚨 ALERTA: Banco de dados StreamLeads está inacessível!"}' \
        "$SLACK_WEBHOOK"
    exit 1
fi

echo "✅ Todos os serviços estão funcionando normalmente"
```

## 💾 Backup e Recovery

### 1. Script de Backup Automatizado

**scripts/backup.sh**:
```bash
#!/bin/bash

set -e

# Configurações
DB_NAME="streamleads_prod"
DB_USER="streamleads_user"
BACKUP_DIR="/backups"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/streamleads_backup_$DATE.sql"
S3_BUCKET="streamleads-backups"

# Criar backup
echo "Iniciando backup do banco de dados..."
pg_dump -h db -U "$DB_USER" -d "$DB_NAME" > "$BACKUP_FILE"

# Comprimir backup
gzip "$BACKUP_FILE"
BACKUP_FILE="$BACKUP_FILE.gz"

# Upload para S3 (se configurado)
if [ ! -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "Enviando backup para S3..."
    aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET/$(basename $BACKUP_FILE)"
fi

# Limpar backups antigos (manter últimos 7 dias)
find "$BACKUP_DIR" -name "streamleads_backup_*.sql.gz" -mtime +7 -delete

echo "Backup concluído: $BACKUP_FILE"
```

### 2. Cron Job para Backups

```bash
# Adicionar ao crontab
# Backup diário às 2:00 AM
0 2 * * * docker-compose -f /path/to/docker-compose.prod.yml --profile backup up backup

# Backup semanal completo aos domingos às 1:00 AM
0 1 * * 0 /path/to/scripts/full-backup.sh
```

### 3. Procedimento de Recovery

**scripts/restore.sh**:
```bash
#!/bin/bash

set -e

BACKUP_FILE="$1"
DB_NAME="streamleads_prod"
DB_USER="streamleads_user"

if [ -z "$BACKUP_FILE" ]; then
    echo "Uso: $0 <arquivo_backup.sql.gz>"
    exit 1
fi

echo "Restaurando backup: $BACKUP_FILE"

# Parar aplicação
docker-compose -f docker-compose.prod.yml stop api streamlit

# Restaurar banco
gunzip -c "$BACKUP_FILE" | docker exec -i streamleads-db psql -U "$DB_USER" -d "$DB_NAME"

# Reiniciar aplicação
docker-compose -f docker-compose.prod.yml start api streamlit

echo "Restore concluído com sucesso!"
```

## 🚀 Deploy Automatizado

### 1. GitHub Actions

**.github/workflows/deploy.yml**:
```yaml
name: Deploy to Production

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
      
      - name: Run tests
        run: |
          pytest tests/ -v
      
      - name: Run security scan
        run: |
          pip install bandit safety
          bandit -r app/
          safety check

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Deploy to server
        uses: appleboy/ssh-action@v0.1.5
        with:
          host: ${{ secrets.HOST }}
          username: ${{ secrets.USERNAME }}
          key: ${{ secrets.SSH_KEY }}
          script: |
            cd /opt/streamleads
            git pull origin main
            docker-compose -f docker-compose.prod.yml pull
            docker-compose -f docker-compose.prod.yml up -d --remove-orphans
            docker system prune -f
      
      - name: Notify Slack
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          channel: '#deployments'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
        if: always()
```

### 2. Script de Deploy Manual

**scripts/deploy.sh**:
```bash
#!/bin/bash

set -e

echo "🚀 Iniciando deploy do StreamLeads..."

# Verificar se está na branch main
if [ "$(git branch --show-current)" != "main" ]; then
    echo "❌ Deploy deve ser feito a partir da branch main"
    exit 1
fi

# Verificar se há mudanças não commitadas
if [ -n "$(git status --porcelain)" ]; then
    echo "❌ Há mudanças não commitadas. Commit antes do deploy."
    exit 1
fi

# Fazer backup antes do deploy
echo "📦 Criando backup..."
docker-compose -f docker-compose.prod.yml --profile backup up backup

# Atualizar código
echo "📥 Atualizando código..."
git pull origin main

# Build das imagens
echo "🔨 Construindo imagens..."
docker-compose -f docker-compose.prod.yml build --no-cache

# Parar serviços
echo "⏹️ Parando serviços..."
docker-compose -f docker-compose.prod.yml stop api streamlit

# Executar migrações
echo "🗃️ Executando migrações..."
docker-compose -f docker-compose.prod.yml run --rm api alembic upgrade head

# Iniciar serviços
echo "▶️ Iniciando serviços..."
docker-compose -f docker-compose.prod.yml up -d

# Verificar saúde dos serviços
echo "🏥 Verificando saúde dos serviços..."
sleep 30

if curl -f -s "https://api.streamleads.com/health" > /dev/null; then
    echo "✅ API está funcionando"
else
    echo "❌ API não está respondendo"
    exit 1
fi

if curl -f -s "https://dashboard.streamleads.com" > /dev/null; then
    echo "✅ Dashboard está funcionando"
else
    echo "❌ Dashboard não está respondendo"
    exit 1
fi

# Limpeza
echo "🧹 Limpando recursos não utilizados..."
docker system prune -f

echo "🎉 Deploy concluído com sucesso!"
```

## 📈 Otimizações de Performance

### 1. Configuração do PostgreSQL

**postgresql.conf**:
```ini
# Conexões
max_connections = 200

# Memória
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB

# WAL
wal_buffers = 16MB
checkpoint_completion_target = 0.9

# Logging
log_statement = 'mod'
log_duration = on
log_min_duration_statement = 1000

# Estatísticas
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
```

### 2. Cache com Redis

**Implementação de cache**:
```python
# app/cache.py
import redis
import json
from typing import Optional, Any
from app.config import settings

redis_client = redis.from_url(settings.REDIS_URL)

class CacheService:
    @staticmethod
    def get(key: str) -> Optional[Any]:
        try:
            value = redis_client.get(key)
            return json.loads(value) if value else None
        except Exception:
            return None
    
    @staticmethod
    def set(key: str, value: Any, expire: int = 3600):
        try:
            redis_client.setex(key, expire, json.dumps(value))
        except Exception:
            pass
    
    @staticmethod
    def delete(key: str):
        try:
            redis_client.delete(key)
        except Exception:
            pass
```

### 3. Connection Pooling

**Configuração do SQLAlchemy**:
```python
# app/database.py
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=20,
    max_overflow=30,
    pool_pre_ping=True,
    pool_recycle=3600,
    echo=False
)
```

## 🔧 Manutenção

### 1. Rotinas de Manutenção

**scripts/maintenance.sh**:
```bash
#!/bin/bash

# Limpeza de logs antigos
find /opt/streamleads/logs -name "*.log" -mtime +30 -delete

# Limpeza de imagens Docker não utilizadas
docker image prune -f

# Análise do banco de dados
docker exec streamleads-db psql -U streamleads_user -d streamleads_prod -c "ANALYZE;"

# Verificar espaço em disco
df -h

# Verificar uso de memória
free -h

# Verificar processos
docker stats --no-stream
```

### 2. Monitoramento de Recursos

**Alertas automáticos**:
```bash
#!/bin/bash
# scripts/resource-monitor.sh

# Verificar uso de disco
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"⚠️ Uso de disco alto: ${DISK_USAGE}%\"}" \
        "$SLACK_WEBHOOK_URL"
fi

# Verificar uso de memória
MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
if [ $MEM_USAGE -gt 85 ]; then
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"⚠️ Uso de memória alto: ${MEM_USAGE}%\"}" \
        "$SLACK_WEBHOOK_URL"
fi
```

---

## 📋 Checklist de Deploy

### Pré-Deploy
- [ ] Testes passando
- [ ] Backup do banco de dados
- [ ] Verificar variáveis de ambiente
- [ ] Revisar logs de erro
- [ ] Verificar espaço em disco

### Durante o Deploy
- [ ] Parar serviços graciosamente
- [ ] Executar migrações
- [ ] Atualizar código
- [ ] Reiniciar serviços
- [ ] Verificar health checks

### Pós-Deploy
- [ ] Testar endpoints críticos
- [ ] Verificar logs de erro
- [ ] Monitorar métricas
- [ ] Notificar equipe
- [ ] Documentar mudanças

---

**Documentação mantida por**: Equipe de DevOps StreamLeads  
**Última atualização**: Janeiro 2024  
**Versão**: 1.0.0