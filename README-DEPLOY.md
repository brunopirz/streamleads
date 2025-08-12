# 🚀 StreamLeads - Guia de Deploy

Este guia fornece instruções completas para fazer o deploy do StreamLeads em diferentes plataformas e ambientes.

## 📋 Índice

- [Pré-requisitos](#pré-requisitos)
- [Deploy no GitHub](#deploy-no-github)
- [Deploy com Docker](#deploy-com-docker)
- [Deploy em Plataformas Cloud](#deploy-em-plataformas-cloud)
- [Configuração de Produção](#configuração-de-produção)
- [Monitoramento](#monitoramento)
- [Troubleshooting](#troubleshooting)

## 🔧 Pré-requisitos

### Requisitos Básicos
- Git
- Docker e Docker Compose
- Conta no GitHub
- Domínio próprio (para produção)
- Servidor/VPS (para deploy próprio)

### Requisitos Opcionais
- Conta na AWS/Google Cloud/Azure
- Conta no Vercel/Railway/Heroku
- Certificado SSL (Let's Encrypt gratuito)

## 🐙 Deploy no GitHub

### 1. Configuração do Repositório

```bash
# Clone o projeto
git clone https://github.com/seu-usuario/streamleads.git
cd streamleads

# Configure o repositório remoto
git remote add origin https://github.com/seu-usuario/streamleads.git

# Faça o primeiro push
git add .
git commit -m "Initial commit"
git push -u origin main
```

### 2. Configuração de Secrets no GitHub

Vá para `Settings > Secrets and variables > Actions` e adicione:

#### Secrets para Staging
```
STAGING_HOST=seu-servidor-staging.com
STAGING_USER=deploy
STAGING_SSH_KEY=sua-chave-ssh-privada
STAGING_PORT=22
```

#### Secrets para Produção
```
PRODUCTION_HOST=seu-servidor.com
PRODUCTION_USER=deploy
PRODUCTION_SSH_KEY=sua-chave-ssh-privada
PRODUCTION_PORT=22
```

#### Secrets para Notificações
```
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

### 3. Configuração do Servidor

#### Preparação do Servidor
```bash
# Conecte ao servidor
ssh deploy@seu-servidor.com

# Instale Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Instale Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Clone o repositório
sudo mkdir -p /opt/streamleads
sudo chown deploy:deploy /opt/streamleads
cd /opt/streamleads
git clone https://github.com/seu-usuario/streamleads.git .
```

#### Configuração de Ambiente
```bash
# Copie e configure o arquivo de ambiente
cp .env.prod.example .env
nano .env

# Configure as variáveis necessárias:
# - DOMAIN=seu-dominio.com
# - SECRET_KEY=sua-chave-secreta
# - POSTGRES_PASSWORD=senha-forte
# - Outras configurações específicas
```

### 4. Deploy Automático

O deploy automático acontece quando:
- **Push para `develop`**: Deploy para staging
- **Release publicada**: Deploy para produção

#### Criando uma Release
```bash
# Via GitHub CLI
gh release create v1.0.0 --title "Release v1.0.0" --notes "Primeira versão estável"

# Ou via Makefile
make release
```

## 🐳 Deploy com Docker

### Deploy Local para Testes

```bash
# Clone o repositório
git clone https://github.com/seu-usuario/streamleads.git
cd streamleads

# Configure ambiente
cp .env.example .env
# Edite .env com suas configurações

# Inicie os serviços
docker-compose up -d

# Verifique os serviços
docker-compose ps
make health
```

### Deploy de Produção

```bash
# Configure ambiente de produção
cp .env.prod.example .env
# Configure todas as variáveis necessárias

# Deploy usando script automatizado
chmod +x scripts/deploy.sh
./scripts/deploy.sh

# Ou usando Makefile
make deploy-prod
```

### Deploy de Staging

```bash
# Configure ambiente de staging
cp .env.staging.example .env.staging
# Configure as variáveis de staging

# Deploy para staging
make deploy-staging
```

## ☁️ Deploy em Plataformas Cloud

### Vercel

```bash
# Instale Vercel CLI
npm i -g vercel

# Configure o projeto
vercel

# Configure variáveis de ambiente no dashboard
# Deploy
vercel --prod
```

### Railway

```bash
# Instale Railway CLI
npm install -g @railway/cli

# Login e configure
railway login
railway init

# Configure variáveis de ambiente
railway variables set DATABASE_URL=...
railway variables set REDIS_URL=...

# Deploy
railway up
```

### Heroku

```bash
# Instale Heroku CLI
# Configure o projeto
heroku create streamleads-app

# Configure add-ons
heroku addons:create heroku-postgresql:hobby-dev
heroku addons:create heroku-redis:hobby-dev

# Configure variáveis
heroku config:set SECRET_KEY=sua-chave
heroku config:set ENVIRONMENT=production

# Deploy
git push heroku main
```

### DigitalOcean App Platform

1. Conecte seu repositório GitHub
2. Configure as variáveis de ambiente
3. Configure os recursos (CPU/RAM)
4. Deploy automático

### AWS ECS/Fargate

```bash
# Configure AWS CLI
aws configure

# Crie cluster ECS
aws ecs create-cluster --cluster-name streamleads

# Configure task definition
# Deploy usando GitHub Actions
```

## ⚙️ Configuração de Produção

### Variáveis de Ambiente Essenciais

```env
# Básico
ENVIRONMENT=production
DEBUG=false
SECRET_KEY=sua-chave-super-secreta
DOMAIN=seu-dominio.com

# Banco de dados
POSTGRES_PASSWORD=senha-muito-forte
DATABASE_URL=postgresql://...

# Redis
REDIS_URL=redis://...

# Email
SMTP_HOST=smtp.gmail.com
SMTP_USER=seu-email@gmail.com
SMTP_PASSWORD=sua-senha-app

# SSL
ACME_EMAIL=admin@seu-dominio.com

# Monitoramento
SENTRY_DSN=https://...
```

### Configuração de SSL

```bash
# Let's Encrypt automático via Traefik
# Já configurado no docker-compose.prod.yml

# Verificar certificados
docker-compose -f docker-compose.prod.yml logs traefik
```

### Backup Automático

```bash
# Configurar backup automático
crontab -e

# Adicionar linha para backup diário às 2h
0 2 * * * cd /opt/streamleads && ./scripts/backup.sh
```

## 📊 Monitoramento

### URLs de Monitoramento

- **API**: `https://api.seu-dominio.com/health`
- **Dashboard**: `https://dashboard.seu-dominio.com`
- **Grafana**: `https://grafana.seu-dominio.com`
- **Prometheus**: `https://prometheus.seu-dominio.com`
- **Flower**: `https://flower.seu-dominio.com`

### Comandos de Monitoramento

```bash
# Status dos serviços
make status
make status-prod

# Verificar saúde
make health
make health-prod

# Ver logs
make logs
make logs-api
make logs-dashboard

# Monitoramento em tempo real
docker stats
```

### Alertas

Configure alertas no Grafana para:
- CPU > 80%
- Memória > 90%
- Disco > 85%
- API response time > 2s
- Erros HTTP 5xx

## 🔧 Troubleshooting

### Problemas Comuns

#### Serviços não iniciam
```bash
# Verificar logs
docker-compose logs

# Verificar recursos
docker stats
df -h

# Reiniciar serviços
docker-compose restart
```

#### SSL não funciona
```bash
# Verificar logs do Traefik
docker-compose logs traefik

# Verificar DNS
nslookup seu-dominio.com

# Verificar portas
netstat -tlnp | grep :80
netstat -tlnp | grep :443
```

#### Banco de dados com problemas
```bash
# Verificar conexão
docker-compose exec api python -c "from app.core.database import engine; print(engine.execute('SELECT 1').scalar())"

# Verificar migrações
docker-compose exec api alembic current
docker-compose exec api alembic upgrade head
```

#### Performance baixa
```bash
# Verificar recursos
docker stats
htop

# Verificar logs de erro
docker-compose logs | grep ERROR

# Otimizar banco
docker-compose exec db psql -U postgres -d streamleads -c "VACUUM ANALYZE;"
```

### Rollback

```bash
# Rollback automático
make rollback

# Rollback manual
git reset --hard HEAD~1
docker-compose down
docker-compose up -d
```

### Backup e Restore

```bash
# Criar backup
make backup

# Restaurar backup
make restore
# Informe o arquivo de backup quando solicitado
```

## 📞 Suporte

Se você encontrar problemas:

1. Verifique os logs: `make logs`
2. Consulte a documentação: `docs/`
3. Verifique issues no GitHub
4. Crie uma nova issue com:
   - Descrição do problema
   - Logs relevantes
   - Passos para reproduzir
   - Ambiente (OS, Docker version, etc.)

## 🎯 Próximos Passos

Após o deploy:

1. ✅ Configure monitoramento
2. ✅ Configure backups automáticos
3. ✅ Configure alertas
4. ✅ Teste todas as funcionalidades
5. ✅ Configure CI/CD
6. ✅ Documente processos específicos
7. ✅ Treine a equipe

---

**🚀 StreamLeads está pronto para produção!**

Para mais informações, consulte:
- [Documentação completa](docs/)
- [Guia de instalação](documentacao/instalacao-plataformas.md)
- [Configurações](docs/configuration.md)