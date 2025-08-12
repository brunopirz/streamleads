.PHONY: help install test lint format clean dev prod backup migration migrate seed docs deploy build status health logs

# Configurações
DOCKER_COMPOSE := docker-compose
DOCKER_COMPOSE_DEV := docker-compose -f docker-compose.yml
DOCKER_COMPOSE_PROD := docker-compose -f docker-compose.prod.yml
DOCKER_COMPOSE_STAGING := docker-compose -f docker-compose.staging.yml
PYTHON := python
PIP := pip

# Cores para output
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[1;33m
BLUE=\033[0;34m
PURPLE=\033[0;35m
CYAN=\033[0;36m
NC=\033[0m # No Color

help: ## Mostrar ajuda
	@echo "$(BLUE)StreamLeads - Comandos Disponíveis$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

install: ## Instalar dependências
	@echo "$(YELLOW)📦 Instalando dependências...$(NC)"
	pip install --upgrade pip
	pip install -r requirements.txt
	pip install -r requirements-dev.txt
	@echo "$(GREEN)✅ Dependências instaladas com sucesso!$(NC)"

install-prod: ## Instalar apenas dependências de produção
	@echo "$(YELLOW)📦 Instalando dependências de produção...$(NC)"
	pip install --upgrade pip
	pip install -r requirements.txt
	@echo "$(GREEN)✅ Dependências de produção instaladas!$(NC)"

test: ## Executar todos os testes
	@echo "$(YELLOW)🧪 Executando testes...$(NC)"
	pytest tests/ -v --cov=app --cov-report=html --cov-report=term-missing
	@echo "$(GREEN)✅ Testes concluídos!$(NC)"

test-unit: ## Executar testes unitários
	@echo "$(YELLOW)🔬 Executando testes unitários...$(NC)"
	pytest tests/unit/ -v -m "unit"

test-integration: ## Executar testes de integração
	@echo "$(YELLOW)🔗 Executando testes de integração...$(NC)"
	pytest tests/integration/ -v -m "integration"

test-e2e: ## Executar testes end-to-end
	@echo "$(YELLOW)🎭 Executando testes E2E...$(NC)"
	pytest tests/e2e/ -v -m "e2e"

test-watch: ## Executar testes em modo watch
	@echo "$(YELLOW)👀 Executando testes em modo watch...$(NC)"
	pytest-watch tests/ -- -v

test-coverage: ## Gerar relatório de cobertura
	@echo "$(YELLOW)📊 Gerando relatório de cobertura...$(NC)"
	pytest tests/ --cov=app --cov-report=html --cov-report=term-missing
	@echo "$(GREEN)📋 Relatório disponível em htmlcov/index.html$(NC)"

lint: ## Executar linting
	@echo "$(YELLOW)🔍 Executando linting...$(NC)"
	flake8 app/ tests/
	mypy app/
	bandit -r app/
	@echo "$(GREEN)✅ Linting concluído!$(NC)"

format: ## Formatar código
	@echo "$(YELLOW)✨ Formatando código...$(NC)"
	black app/ tests/ scripts/ dashboard/
	isort app/ tests/ scripts/ dashboard/
	@echo "$(GREEN)✅ Código formatado!$(NC)"

format-check: ## Verificar formatação sem alterar
	@echo "$(YELLOW)🔍 Verificando formatação...$(NC)"
	black --check app/ tests/ scripts/ dashboard/
	isort --check-only app/ tests/ scripts/ dashboard/

clean: ## Limpar arquivos temporários
	@echo "$(YELLOW)🧹 Limpando arquivos temporários...$(NC)"
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	find . -type d -name ".pytest_cache" -delete
	rm -rf htmlcov/
	rm -rf .coverage
	rm -rf .mypy_cache/
	rm -rf dist/
	rm -rf build/
	rm -rf *.egg-info/
	@echo "$(GREEN)✅ Limpeza concluída!$(NC)"

dev-setup: ## Configurar ambiente de desenvolvimento
	@echo "$(YELLOW)🚀 Configurando ambiente de desenvolvimento...$(NC)"
	docker-compose -f docker-compose.dev.yml up -d db redis
	@echo "$(YELLOW)⏳ Aguardando serviços iniciarem...$(NC)"
	sleep 10
	alembic upgrade head
	python scripts/init_db.py
	@echo "$(GREEN)✅ Ambiente configurado!$(NC)"

dev: ## Iniciar servidor de desenvolvimento
	@echo "$(YELLOW)🚀 Iniciando servidor de desenvolvimento...$(NC)"
	uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

dev-api: ## Iniciar apenas a API
	@echo "$(YELLOW)🔌 Iniciando API...$(NC)"
	uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

dev-dashboard: ## Iniciar dashboard Streamlit
	@echo "$(YELLOW)📊 Iniciando dashboard...$(NC)"
	streamlit run dashboard/main.py --server.port 8501

dev-services: ## Iniciar serviços Docker para desenvolvimento
	@echo "$(YELLOW)🐳 Iniciando serviços Docker...$(NC)"
	docker-compose -f docker-compose.dev.yml up -d

dev-stop: ## Parar serviços de desenvolvimento
	@echo "$(YELLOW)🛑 Parando serviços...$(NC)"
	docker-compose -f docker-compose.dev.yml down

dev-logs: ## Ver logs dos serviços
	docker-compose -f docker-compose.dev.yml logs -f

prod: ## Deploy em produção
	@echo "$(YELLOW)🚀 Fazendo deploy em produção...$(NC)"
	docker-compose -f docker-compose.prod.yml up -d
	@echo "$(GREEN)✅ Deploy concluído!$(NC)"

prod-build: ## Build das imagens de produção
	@echo "$(YELLOW)🔨 Fazendo build das imagens...$(NC)"
	docker-compose -f docker-compose.prod.yml build

prod-stop: ## Parar produção
	@echo "$(YELLOW)🛑 Parando produção...$(NC)"
	docker-compose -f docker-compose.prod.yml down

prod-logs: ## Ver logs de produção
	docker-compose -f docker-compose.prod.yml logs -f

backup: ## Fazer backup do banco
	@echo "$(YELLOW)💾 Fazendo backup do banco...$(NC)"
	docker-compose exec db pg_dump -U postgres streamleads > backup_$(shell date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)✅ Backup concluído!$(NC)"

restore: ## Restaurar backup (usar: make restore BACKUP_FILE=backup.sql)
	@echo "$(YELLOW)🔄 Restaurando backup...$(NC)"
	@if [ -z "$(BACKUP_FILE)" ]; then echo "$(RED)❌ Especifique o arquivo: make restore BACKUP_FILE=backup.sql$(NC)"; exit 1; fi
	docker-compose exec -T db psql -U postgres streamleads < $(BACKUP_FILE)
	@echo "$(GREEN)✅ Backup restaurado!$(NC)"

migration: ## Criar nova migração (usar: make migration MSG="descrição")
	@echo "$(YELLOW)📝 Criando migração...$(NC)"
	@if [ -z "$(MSG)" ]; then echo "$(RED)❌ Especifique a mensagem: make migration MSG='descrição'$(NC)"; exit 1; fi
	alembic revision --autogenerate -m "$(MSG)"
	@echo "$(GREEN)✅ Migração criada!$(NC)"

migrate: ## Executar migrações
	@echo "$(YELLOW)🗃️ Executando migrações...$(NC)"
	alembic upgrade head
	@echo "$(GREEN)✅ Migrações executadas!$(NC)"

migrate-down: ## Reverter última migração
	@echo "$(YELLOW)⬇️ Revertendo migração...$(NC)"
	alembic downgrade -1
	@echo "$(GREEN)✅ Migração revertida!$(NC)"

seed: ## Popular banco com dados de exemplo
	@echo "$(YELLOW)🌱 Populando banco...$(NC)"
	python scripts/init_db.py
	@echo "$(GREEN)✅ Banco populado!$(NC)"

db-reset: ## Resetar banco de dados
	@echo "$(YELLOW)🔄 Resetando banco...$(NC)"
	docker-compose exec db psql -U postgres -c "DROP DATABASE IF EXISTS streamleads;"
	docker-compose exec db psql -U postgres -c "CREATE DATABASE streamleads;"
	alembic upgrade head
	python scripts/init_db.py
	@echo "$(GREEN)✅ Banco resetado!$(NC)"

docs: ## Gerar documentação
	@echo "$(YELLOW)📚 Gerando documentação...$(NC)"
	mkdocs build
	@echo "$(GREEN)✅ Documentação gerada em site/$(NC)"

docs-serve: ## Servir documentação localmente
	@echo "$(YELLOW)📖 Servindo documentação...$(NC)"
	mkdocs serve

security: ## Verificar vulnerabilidades de segurança
	@echo "$(YELLOW)🔒 Verificando segurança...$(NC)"
	safety check
	bandit -r app/
	@echo "$(GREEN)✅ Verificação de segurança concluída!$(NC)"

performance: ## Executar testes de performance
	@echo "$(YELLOW)⚡ Executando testes de performance...$(NC)"
	locust -f tests/performance/locustfile.py --headless -u 10 -r 2 -t 30s --host http://localhost:8000

check: ## Executar todas as verificações (lint, test, security)
	@echo "$(YELLOW)🔍 Executando todas as verificações...$(NC)"
	make format-check
	make lint
	make test
	make security
	@echo "$(GREEN)✅ Todas as verificações concluídas!$(NC)"

ci: ## Executar pipeline de CI
	@echo "$(YELLOW)🔄 Executando pipeline de CI...$(NC)"
	make install
	make check
	@echo "$(GREEN)✅ Pipeline de CI concluído!$(NC)"

release: ## Preparar release
	@echo "$(YELLOW)🚀 Preparando release...$(NC)"
	make check
	make prod-build
	@echo "$(GREEN)✅ Release preparado!$(NC)"

status: ## Verificar status dos serviços
	@echo "$(BLUE)📊 Status dos Serviços$(NC)"
	@echo ""
	@echo "$(YELLOW)Docker Containers:$(NC)"
	docker-compose ps
	@echo ""
	@echo "$(YELLOW)API Health:$(NC)"
	@curl -s http://localhost:8000/health || echo "$(RED)❌ API não disponível$(NC)"
	@echo ""
	@echo "$(YELLOW)Dashboard:$(NC)"
	@curl -s http://localhost:8501 > /dev/null && echo "$(GREEN)✅ Dashboard disponível$(NC)" || echo "$(RED)❌ Dashboard não disponível$(NC)"

monitor: ## Monitorar logs em tempo real
	@echo "$(YELLOW)👀 Monitorando logs...$(NC)"
	docker-compose logs -f

shell: ## Abrir shell no container da API
	@echo "$(YELLOW)🐚 Abrindo shell...$(NC)"
	docker-compose exec api bash

db-shell: ## Abrir shell do PostgreSQL
	@echo "$(YELLOW)🗄️ Abrindo shell do banco...$(NC)"
	docker-compose exec db psql -U postgres streamleads

redis-shell: ## Abrir shell do Redis
	@echo "$(YELLOW)🔴 Abrindo shell do Redis...$(NC)"
	docker-compose exec redis redis-cli

update: ## Atualizar dependências
	@echo "$(YELLOW)🔄 Atualizando dependências...$(NC)"
	pip-compile requirements.in
	pip-compile requirements-dev.in
	pip install -r requirements.txt
	pip install -r requirements-dev.txt
	@echo "$(GREEN)✅ Dependências atualizadas!$(NC)"

info: ## Mostrar informações do projeto
	@echo "$(BLUE)📋 Informações do Projeto$(NC)"
	@echo ""
	@echo "$(YELLOW)Projeto:$(NC) StreamLeads"
	@echo "$(YELLOW)Versão:$(NC) 1.0.0"
	@echo "$(YELLOW)Python:$(NC) $(shell python --version)"
	@echo "$(YELLOW)Docker:$(NC) $(shell docker --version)"
	@echo "$(YELLOW)Docker Compose:$(NC) $(shell docker-compose --version)"
	@echo ""
	@echo "$(YELLOW)URLs:$(NC)"
	@echo "  API: http://localhost:8000"
	@echo "  Dashboard: http://localhost:8501"
	@echo "  Docs: http://localhost:8000/docs"
	@echo "  Redoc: http://localhost:8000/redoc"

quick-start: ## Setup rápido para desenvolvimento
	@echo "$(BLUE)🚀 Setup Rápido StreamLeads$(NC)"
	make install
	make setup-env
	make dev

# =============================================================================
# DEPLOY E AUTOMAÇÃO
# =============================================================================
build: ## Constrói imagens Docker
	@echo "$(BLUE)🏗️  Construindo imagens...$(NC)"
	docker build -t streamleads:latest .
	@echo "$(GREEN)✅ Imagens construídas!$(NC)"

build-prod: ## Constrói imagens para produção
	@echo "$(BLUE)🏗️  Construindo imagens para produção...$(NC)"
	$(DOCKER_COMPOSE_PROD) build --no-cache
	@echo "$(GREEN)✅ Imagens de produção construídas!$(NC)"

build-staging: ## Constrói imagens para staging
	@echo "$(BLUE)🏗️  Construindo imagens para staging...$(NC)"
	$(DOCKER_COMPOSE_STAGING) build --no-cache
	@echo "$(GREEN)✅ Imagens de staging construídas!$(NC)"

deploy-staging: ## Deploy para staging
	@echo "$(BLUE)🚀 Fazendo deploy para staging...$(NC)"
	$(DOCKER_COMPOSE_STAGING) down
	$(DOCKER_COMPOSE_STAGING) pull
	$(DOCKER_COMPOSE_STAGING) up -d
	@echo "$(GREEN)✅ Deploy para staging concluído!$(NC)"

deploy-prod: ## Deploy para produção
	@echo "$(BLUE)🚀 Fazendo deploy para produção...$(NC)"
	@echo "$(RED)⚠️  ATENÇÃO: Deploy para PRODUÇÃO!$(NC)"
	@read -p "Tem certeza? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	chmod +x scripts/deploy.sh
	./scripts/deploy.sh
	@echo "$(GREEN)✅ Deploy para produção concluído!$(NC)"

rollback: ## Faz rollback da produção
	@echo "$(YELLOW)🔄 Fazendo rollback...$(NC)"
	chmod +x scripts/deploy.sh
	./scripts/deploy.sh rollback
	@echo "$(GREEN)✅ Rollback concluído!$(NC)"

status: ## Mostra status dos serviços
	@echo "$(BLUE)📊 Status dos serviços:$(NC)"
	$(DOCKER_COMPOSE_DEV) ps

status-prod: ## Mostra status da produção
	@echo "$(BLUE)📊 Status da produção:$(NC)"
	$(DOCKER_COMPOSE_PROD) ps

health: ## Verifica saúde dos serviços
	@echo "$(BLUE)🏥 Verificando saúde dos serviços...$(NC)"
	@curl -f http://localhost:8000/health && echo "$(GREEN)✅ API OK$(NC)" || echo "$(RED)❌ API FALHOU$(NC)"
	@curl -f http://localhost:8501/_stcore/health && echo "$(GREEN)✅ Dashboard OK$(NC)" || echo "$(RED)❌ Dashboard FALHOU$(NC)"

health-prod: ## Verifica saúde da produção
	@echo "$(BLUE)🏥 Verificando saúde da produção...$(NC)"
	chmod +x scripts/deploy.sh
	./scripts/deploy.sh health

logs: ## Mostra logs dos serviços
	@echo "$(BLUE)📋 Mostrando logs...$(NC)"
	$(DOCKER_COMPOSE_DEV) logs -f

logs-api: ## Mostra logs da API
	$(DOCKER_COMPOSE_DEV) logs -f api

logs-dashboard: ## Mostra logs do dashboard
	$(DOCKER_COMPOSE_DEV) logs -f dashboard

logs-worker: ## Mostra logs do worker
	$(DOCKER_COMPOSE_DEV) logs -f worker

logs-prod: ## Mostra logs da produção
	$(DOCKER_COMPOSE_PROD) logs -f

monitor: ## Abre ferramentas de monitoramento
	@echo "$(CYAN)📈 Ferramentas de monitoramento:$(NC)"
	@echo "$(CYAN)Grafana: http://localhost:3000$(NC)"
	@echo "$(CYAN)Prometheus: http://localhost:9090$(NC)"
	@echo "$(CYAN)Flower: http://localhost:5555$(NC)"

setup-env: ## Configura arquivos de ambiente
	@echo "$(BLUE)🔧 Configurando arquivos de ambiente...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)⚠️  Criando arquivo .env...$(NC)"; \
		cp .env.example .env; \
	fi
	@if [ ! -f .env.test ]; then \
		echo "$(YELLOW)⚠️  Criando arquivo .env.test...$(NC)"; \
		cp .env.test.example .env.test; \
	fi
	@echo "$(GREEN)✅ Arquivos de ambiente configurados!$(NC)"

release: ## Cria uma nova release
	@echo "$(BLUE)🏷️  Criando release...$(NC)"
	@read -p "Versão (ex: v1.0.0): " version; \
	git tag -a $$version -m "Release $$version"; \
	git push origin $$version
	@echo "$(GREEN)✅ Release criada!$(NC)"
	@echo ""
	make install
	make dev-setup
	@echo ""
	@echo "$(GREEN)✅ Setup concluído!$(NC)"
	@echo "$(YELLOW)Para iniciar:$(NC)"
	@echo "  make dev      # API"
	@echo "  make dev-dashboard  # Dashboard"

default: help