# 🚀 StreamLeads - Sistema de Automação de Leads

Sistema completo para receber, processar e qualificar leads automaticamente de múltiplas origens, aplicando regras de negócio personalizadas e executando ações automáticas baseadas no status do lead.

## 📋 Funcionalidades

### 🎯 Core Features
- **Recebimento de Leads**: API REST para receber leads de múltiplas origens
- **Scoring Automático**: Qualificação baseada em regras de negócio configuráveis
- **Automações Inteligentes**: Ações automáticas baseadas no status do lead
- **Dashboard Interativo**: Interface em Streamlit para visualização e gestão
- **Integração n8n**: Webhooks para automações externas

### 📊 Classificação de Leads
- **Lead Quente** (≥25 pontos): Enviado imediatamente para vendas
- **Lead Morno** (15-24 pontos): Nutrição via email e follow-up
- **Lead Frio** (<15 pontos): Inserido no CRM para follow-up futuro

### ⚡ Automações
- **Leads Quentes**: Notificação imediata para vendas via Slack/WhatsApp
- **Leads Mornos**: Email de nutrição com PDF e agendamento
- **Leads Frios**: Inserção no CRM com data de follow-up

## 🛠️ Stack Tecnológica

- **Backend**: Python + FastAPI
- **Banco de Dados**: PostgreSQL
- **Frontend**: Streamlit
- **Orquestração**: n8n (opcional)
- **Deploy**: Docker + Docker Compose
- **Proxy**: Traefik (para produção)

## 📦 Instalação

### Pré-requisitos
- Python 3.11+
- Docker e Docker Compose
- Git

### 1. Clone o Repositório
```bash
git clone <repository-url>
cd StreamLeads
```

### 2. Configuração do Ambiente

#### Opção A: Docker (Recomendado)
```bash
# Copiar arquivo de ambiente
cp .env.example .env

# Editar configurações se necessário
# nano .env

# Iniciar todos os serviços
docker-compose up -d
```

#### Opção B: Instalação Local
```bash
# Criar ambiente virtual
python -m venv venv

# Ativar ambiente virtual
# Windows
venv\Scripts\activate
# Linux/Mac
source venv/bin/activate

# Instalar dependências
pip install -r requirements.txt

# Configurar banco PostgreSQL local
# Editar .env com suas configurações

# Inicializar banco de dados
python scripts/init_db.py
```

### 3. Inicialização

```bash
# Inicializar banco com dados de exemplo
python scripts/init_db.py

# Iniciar API (se não usando Docker)
uvicorn app.main:app --reload

# Iniciar Dashboard (se não usando Docker)
streamlit run dashboard/main.py
```

## 🚀 Uso

### API Endpoints

#### Criar Lead
```bash
curl -X POST "http://localhost:8000/api/v1/leads" \
  -H "Content-Type: application/json" \
  -d '{
    "nome": "João Silva",
    "email": "joao@email.com",
    "telefone": "11999999999",
    "origem": "Meta Ads",
    "interesse": "Imóvel na Zona Sul",
    "renda_aproximada": 8000,
    "cidade": "São Paulo"
  }'
```

#### Listar Leads
```bash
curl "http://localhost:8000/api/v1/leads?status=quente&page=1&per_page=20"
```

#### Buscar Lead Específico
```bash
curl "http://localhost:8000/api/v1/leads/1"
```

#### Atualizar Lead
```bash
curl -X PUT "http://localhost:8000/api/v1/leads/1" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "quente",
    "observacoes": "Lead muito interessado"
  }'
```

### Dashboard

Acesse o dashboard em: `http://localhost:8501`

**Páginas disponíveis:**
- **📈 Overview**: Estatísticas e gráficos em tempo real
- **📋 Leads**: Lista completa com filtros avançados
- **🔍 Detalhes**: Visualização detalhada de leads individuais
- **⚙️ Configurações**: Configurações do sistema

### Documentação da API

Acesse a documentação interativa em:
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

## 🎯 Regras de Scoring

### Pontuação Base
- **Campos obrigatórios preenchidos**: +10 pontos
- **Interesse em produto de alto ticket**: +15 pontos
- **Região atendida pela empresa**: +5 pontos

### Bônus por Renda
- **≥ R$ 20.000**: +10 pontos
- **≥ R$ 10.000**: +7 pontos
- **≥ R$ 5.000**: +5 pontos
- **≥ R$ 3.000**: +3 pontos

### Palavras-chave Alto Ticket
- imóvel, apartamento, casa, terreno, lote
- investimento, premium, luxo, cobertura
- comercial, empresarial, corporativo

### Regiões Atendidas
- São Paulo, Rio de Janeiro, Belo Horizonte
- Brasília, Salvador, Fortaleza, Recife
- Porto Alegre, Curitiba, Goiânia
- Campinas, Santos, Osasco

## 🔧 Configuração

### Variáveis de Ambiente (.env)

```env
# Database
DATABASE_URL=postgresql://postgres:postgres123@localhost:5432/streamleads

# Application
ENVIRONMENT=development
API_HOST=0.0.0.0
API_PORT=8000
DEBUG=True

# Security
SECRET_KEY=your-secret-key-here

# External Integrations
N8N_WEBHOOK_URL=http://localhost:5678/webhook
WHATSAPP_API_TOKEN=your-whatsapp-token
SLACK_WEBHOOK_URL=your-slack-webhook-url

# Email Configuration
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
EMAIL_USER=your-email@gmail.com
EMAIL_PASSWORD=your-app-password

# Scoring Configuration
SCORE_REQUIRED_FIELDS=10
SCORE_HIGH_TICKET=15
SCORE_REGION=5
HOT_LEAD_THRESHOLD=25
WARM_LEAD_THRESHOLD=15
```

### Integração com n8n

1. Configure o webhook URL no arquivo `.env`
2. Crie workflows no n8n para:
   - Integração com CRMs (HubSpot, Pipedrive)
   - Envio de emails automatizados
   - Integração com Google Sheets
   - Notificações via WhatsApp/Slack

### Integração com Slack

1. Crie um webhook no Slack
2. Configure `SLACK_WEBHOOK_URL` no `.env`
3. Leads quentes serão notificados automaticamente

## 📈 Monitoramento

### Health Check
```bash
curl http://localhost:8000/health
```

### Logs
- **Aplicação**: `logs/streamleads.log`
- **Docker**: `docker-compose logs -f`

### Métricas
- Total de leads processados
- Taxa de conversão por origem
- Distribuição de scores
- Performance das automações

## 🔄 Deploy em Produção

### Docker Compose (Recomendado)

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  traefik:
    image: traefik:v2.10
    command:
      - --api.dashboard=true
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --providers.docker=true
      - --certificatesresolvers.letsencrypt.acme.email=your-email@domain.com
      - --certificatesresolvers.letsencrypt.acme.storage=/acme.json
      - --certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./acme.json:/acme.json
    labels:
      - traefik.http.routers.api.rule=Host(`traefik.yourdomain.com`)
      - traefik.http.routers.api.tls.certresolver=letsencrypt

  api:
    build: .
    environment:
      - DATABASE_URL=postgresql://postgres:${POSTGRES_PASSWORD}@db:5432/streamleads
      - ENVIRONMENT=production
      - DEBUG=False
    labels:
      - traefik.http.routers.api.rule=Host(`api.yourdomain.com`)
      - traefik.http.routers.api.tls.certresolver=letsencrypt
    depends_on:
      - db

  dashboard:
    build: .
    command: streamlit run dashboard/main.py --server.port=8501 --server.address=0.0.0.0
    labels:
      - traefik.http.routers.dashboard.rule=Host(`dashboard.yourdomain.com`)
      - traefik.http.routers.dashboard.tls.certresolver=letsencrypt
    depends_on:
      - api
```

### Deploy
```bash
# Produção
docker-compose -f docker-compose.prod.yml up -d

# Backup do banco
docker-compose exec db pg_dump -U postgres streamleads > backup.sql
```

## 🧪 Testes

```bash
# Instalar dependências de teste
pip install pytest pytest-asyncio httpx

# Executar testes
pytest tests/

# Executar com cobertura
pytest --cov=app tests/
```

## 📚 Estrutura do Projeto

```
StreamLeads/
├── app/
│   ├── api/
│   │   └── leads.py          # Rotas da API
│   ├── models/
│   │   └── lead.py           # Modelos SQLAlchemy
│   ├── repositories/
│   │   └── lead_repository.py # Operações de banco
│   ├── schemas/
│   │   └── lead.py           # Schemas Pydantic
│   ├── services/
│   │   ├── scoring.py        # Lógica de scoring
│   │   └── automation.py     # Automações
│   ├── config.py             # Configurações
│   ├── database.py           # Configuração do banco
│   └── main.py               # Aplicação FastAPI
├── dashboard/
│   └── main.py               # Dashboard Streamlit
├── scripts/
│   └── init_db.py            # Inicialização do banco
├── tests/                    # Testes automatizados
├── logs/                     # Arquivos de log
├── docker-compose.yml        # Orquestração Docker
├── Dockerfile               # Imagem Docker
├── requirements.txt         # Dependências Python
└── README.md               # Documentação
```

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo `LICENSE` para mais detalhes.

## 📞 Suporte

- **Email**: support@streamleads.com
- **Documentação**: [docs.streamleads.com](http://docs.streamleads.com)
- **Issues**: [GitHub Issues](https://github.com/your-repo/streamleads/issues)

## 🎉 Próximos Passos

- [ ] Integração com WhatsApp Business API
- [ ] Machine Learning para scoring preditivo
- [ ] App mobile para gestão de leads
- [ ] Integração com mais CRMs
- [ ] Analytics avançados com BI
- [ ] API de webhooks para eventos
- [ ] Sistema de templates de email
- [ ] Automação de follow-up inteligente

---

**Desenvolvido com ❤️ para automatizar e otimizar a gestão de leads**