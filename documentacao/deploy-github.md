# 🚀 Deploy no GitHub - StreamLeads

## Visão Geral

Este guia detalha como fazer o deploy do projeto StreamLeads no GitHub e configurar integração contínua com GitHub Actions.

## 📋 Pré-requisitos

- Conta no GitHub
- Git configurado localmente
- Docker Hub account (opcional)
- Servidor para deploy (VPS, AWS, etc.)

## 🔧 Configuração Inicial

### 1. Criar Repositório no GitHub

```bash
# Criar repositório no GitHub (via web interface)
# Depois localmente:
git remote add origin https://github.com/seu-usuario/streamleads.git
git branch -M main
git push -u origin main
```

### 2. Configurar Secrets no GitHub

Vá em **Settings > Secrets and variables > Actions** e adicione:

```bash
# Servidor de Deploy
HOST=seu-servidor.com
USERNAME=deploy-user
SSH_KEY=sua-chave-ssh-privada

# Docker Hub (opcional)
DOCKER_USERNAME=seu-usuario-docker
DOCKER_PASSWORD=sua-senha-docker

# Banco de Dados
DB_PASSWORD=senha-super-segura
DB_NAME=streamleads_prod
DB_USER=streamleads_user

# Aplicação
SECRET_KEY=chave-secreta-jwt
DOMAIN=streamleads.com
ACME_EMAIL=admin@streamleads.com

# Notificações (opcional)
SLACK_WEBHOOK=https://hooks.slack.com/...
DISCORD_WEBHOOK=https://discord.com/api/webhooks/...
```

## 🔄 GitHub Actions Workflows

### Workflow Principal: `.github/workflows/ci-cd.yml`

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

env:
  PYTHON_VERSION: '3.11'
  NODE_VERSION: '18'

jobs:
  test:
    name: 🧪 Tests
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
      
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379
    
    steps:
    - name: 📥 Checkout code
      uses: actions/checkout@v4
    
    - name: 🐍 Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: ${{ env.PYTHON_VERSION }}
        cache: 'pip'
    
    - name: 📦 Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
        pip install -r requirements-dev.txt
    
    - name: 🔍 Lint with flake8
      run: |
        flake8 app/ tests/ --count --select=E9,F63,F7,F82 --show-source --statistics
        flake8 app/ tests/ --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics
    
    - name: 🎯 Type check with mypy
      run: mypy app/
    
    - name: 🔒 Security check with bandit
      run: bandit -r app/ -f json -o bandit-report.json
    
    - name: 📊 Test with pytest
      env:
        DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test_db
        REDIS_URL: redis://localhost:6379/0
        SECRET_KEY: test-secret-key
        ENVIRONMENT: test
      run: |
        pytest tests/ -v --cov=app --cov-report=xml --cov-report=html
    
    - name: 📈 Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.xml
        flags: unittests
        name: codecov-umbrella

  security:
    name: 🔒 Security Scan
    runs-on: ubuntu-latest
    
    steps:
    - name: 📥 Checkout code
      uses: actions/checkout@v4
    
    - name: 🐍 Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: ${{ env.PYTHON_VERSION }}
    
    - name: 🔍 Run safety check
      run: |
        pip install safety
        safety check --json --output safety-report.json || true
    
    - name: 🔒 Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
    
    - name: 📤 Upload Trivy scan results
      uses: github/codeql-action/upload-sarif@v2
      if: always()
      with:
        sarif_file: 'trivy-results.sarif'

  build:
    name: 🏗️ Build Docker Images
    runs-on: ubuntu-latest
    needs: [test, security]
    if: github.ref == 'refs/heads/main'
    
    steps:
    - name: 📥 Checkout code
      uses: actions/checkout@v4
    
    - name: 🐳 Set up Docker Buildx
      uses: docker/setup-buildx-action@v3
    
    - name: 🔑 Login to Docker Hub
      uses: docker/login-action@v3
      with:
        username: ${{ secrets.DOCKER_USERNAME }}
        password: ${{ secrets.DOCKER_PASSWORD }}
    
    - name: 🏷️ Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ secrets.DOCKER_USERNAME }}/streamleads
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=sha,prefix={{branch}}-
          type=raw,value=latest,enable={{is_default_branch}}
    
    - name: 🏗️ Build and push Docker image
      uses: docker/build-push-action@v5
      with:
        context: .
        target: production
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max

  deploy:
    name: 🚀 Deploy to Production
    runs-on: ubuntu-latest
    needs: [build]
    if: github.ref == 'refs/heads/main'
    environment: production
    
    steps:
    - name: 📥 Checkout code
      uses: actions/checkout@v4
    
    - name: 🚀 Deploy to server
      uses: appleboy/ssh-action@v1.0.0
      with:
        host: ${{ secrets.HOST }}
        username: ${{ secrets.USERNAME }}
        key: ${{ secrets.SSH_KEY }}
        script: |
          cd /opt/streamleads
          
          # Backup atual
          docker-compose -f docker-compose.prod.yml down
          
          # Atualizar código
          git pull origin main
          
          # Atualizar imagens
          docker-compose -f docker-compose.prod.yml pull
          
          # Executar migrações
          docker-compose -f docker-compose.prod.yml run --rm api alembic upgrade head
          
          # Iniciar serviços
          docker-compose -f docker-compose.prod.yml up -d
          
          # Limpeza
          docker system prune -f
          
          # Health check
          sleep 30
          curl -f http://localhost/health || exit 1
    
    - name: 📱 Notify Slack
      uses: 8398a7/action-slack@v3
      with:
        status: ${{ job.status }}
        channel: '#deployments'
        webhook_url: ${{ secrets.SLACK_WEBHOOK }}
        fields: repo,message,commit,author,action,eventName,ref,workflow
      if: always() && secrets.SLACK_WEBHOOK
    
    - name: 📱 Notify Discord
      uses: Ilshidur/action-discord@master
      env:
        DISCORD_WEBHOOK: ${{ secrets.DISCORD_WEBHOOK }}
      with:
        args: '🚀 Deploy realizado com sucesso! Commit: {{ EVENT_PAYLOAD.head_commit.message }}'
      if: success() && secrets.DISCORD_WEBHOOK
```

### Workflow de Release: `.github/workflows/release.yml`

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    name: 🏷️ Create Release
    runs-on: ubuntu-latest
    
    steps:
    - name: 📥 Checkout code
      uses: actions/checkout@v4
      with:
        fetch-depth: 0
    
    - name: 📝 Generate changelog
      id: changelog
      uses: mikepenz/release-changelog-builder-action@v4
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    
    - name: 🏷️ Create Release
      uses: actions/create-release@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        tag_name: ${{ github.ref }}
        release_name: Release ${{ github.ref }}
        body: ${{ steps.changelog.outputs.changelog }}
        draft: false
        prerelease: false
```

## 🔧 Configuração do Servidor

### 1. Preparar Servidor

```bash
# Conectar ao servidor
ssh deploy-user@seu-servidor.com

# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Criar diretório do projeto
sudo mkdir -p /opt/streamleads
sudo chown $USER:$USER /opt/streamleads
cd /opt/streamleads

# Clonar repositório
git clone https://github.com/seu-usuario/streamleads.git .
```

### 2. Configurar Ambiente de Produção

```bash
# Criar arquivo .env para produção
cp .env.example .env
nano .env
```

**Exemplo de `.env` para produção:**
```bash
# Ambiente
ENVIRONMENT=production
DEBUG=False
SECRET_KEY=sua-chave-super-secreta-aqui

# Domínio
DOMAIN=streamleads.com
ACME_EMAIL=admin@streamleads.com

# Banco de Dados
DB_HOST=db
DB_PORT=5432
DB_NAME=streamleads_prod
DB_USER=streamleads_user
DB_PASSWORD=senha-super-segura
DATABASE_URL=postgresql://streamleads_user:senha-super-segura@db:5432/streamleads_prod

# Redis
REDIS_URL=redis://redis:6379/0

# Email (opcional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=noreply@streamleads.com
SMTP_PASSWORD=senha-email

# Integrações (opcional)
N8N_WEBHOOK_URL=https://n8n.streamleads.com/webhook
ZAPIER_WEBHOOK_URL=https://hooks.zapier.com/...
```

### 3. Configurar SSL com Let's Encrypt

```bash
# Criar arquivo acme.json
touch acme.json
chmod 600 acme.json

# Iniciar Traefik para gerar certificados
docker-compose -f docker-compose.prod.yml up -d traefik

# Verificar logs
docker-compose -f docker-compose.prod.yml logs traefik
```

## 🔄 Processo de Deploy

### Deploy Manual

```bash
# No servidor
cd /opt/streamleads

# Atualizar código
git pull origin main

# Rebuild e restart
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d

# Executar migrações
docker-compose -f docker-compose.prod.yml exec api alembic upgrade head

# Verificar status
docker-compose -f docker-compose.prod.yml ps
curl -f https://api.streamleads.com/health
```

### Deploy Automático via GitHub Actions

1. **Push para main**: Automaticamente executa CI/CD
2. **Pull Request**: Executa apenas testes
3. **Tag de release**: Cria release no GitHub

## 📊 Monitoramento

### Health Checks

```bash
# Verificar status dos serviços
curl https://api.streamleads.com/health
curl https://dashboard.streamleads.com/_stcore/health

# Logs em tempo real
docker-compose -f docker-compose.prod.yml logs -f api
docker-compose -f docker-compose.prod.yml logs -f dashboard
```

### Métricas

- **Prometheus**: http://prometheus.streamleads.com
- **Grafana**: http://grafana.streamleads.com
- **Traefik Dashboard**: http://traefik.streamleads.com

## 🔧 Troubleshooting

### Problemas Comuns

**1. Falha no SSL**
```bash
# Verificar configuração do Traefik
docker-compose -f docker-compose.prod.yml logs traefik

# Recriar certificados
docker-compose -f docker-compose.prod.yml restart traefik
```

**2. Banco de dados não conecta**
```bash
# Verificar status do PostgreSQL
docker-compose -f docker-compose.prod.yml exec db pg_isready -U postgres

# Verificar logs
docker-compose -f docker-compose.prod.yml logs db
```

**3. Aplicação não inicia**
```bash
# Verificar logs da API
docker-compose -f docker-compose.prod.yml logs api

# Verificar variáveis de ambiente
docker-compose -f docker-compose.prod.yml exec api env
```

## 🔄 Rollback

### Rollback Rápido

```bash
# Voltar para commit anterior
git reset --hard HEAD~1
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d
```

### Rollback de Migração

```bash
# Reverter última migração
docker-compose -f docker-compose.prod.yml exec api alembic downgrade -1
```

## 📝 Checklist de Deploy

### Antes do Deploy
- [ ] Testes passando localmente
- [ ] Código revisado (Pull Request)
- [ ] Variáveis de ambiente configuradas
- [ ] Backup do banco de dados
- [ ] Certificados SSL válidos

### Durante o Deploy
- [ ] CI/CD executado com sucesso
- [ ] Migrações aplicadas
- [ ] Serviços iniciados
- [ ] Health checks passando

### Após o Deploy
- [ ] Funcionalidades testadas
- [ ] Logs verificados
- [ ] Métricas normais
- [ ] Notificação da equipe

---

**Documentação mantida por**: Equipe de Desenvolvimento StreamLeads  
**Última atualização**: Dezembro 2024  
**Versão**: 1.0.0