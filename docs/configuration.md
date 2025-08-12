# Configuração do Projeto StreamLeads

Este documento descreve todos os arquivos de configuração criados para o projeto StreamLeads e suas finalidades.

## 📁 Estrutura de Configuração

### Arquivos de Configuração Principal

#### `.env` e `.env.example`
- **Finalidade**: Variáveis de ambiente para configuração da aplicação
- **Conteúdo**: URLs de banco, chaves secretas, configurações de API
- **Uso**: Copie `.env.example` para `.env` e ajuste as variáveis

#### `pyproject.toml`
- **Finalidade**: Configuração moderna do projeto Python (PEP 518)
- **Conteúdo**: Metadados do projeto, dependências, configurações de ferramentas
- **Ferramentas configuradas**: Black, isort, pytest, coverage, mypy, bandit, pylint

#### `setup.cfg`
- **Finalidade**: Configuração alternativa para ferramentas que não suportam pyproject.toml
- **Conteúdo**: Configurações de flake8, coverage, isort, mypy, pydocstyle

### Arquivos de Qualidade de Código

#### `.pre-commit-config.yaml`
- **Finalidade**: Hooks de pré-commit para garantir qualidade do código
- **Hooks incluídos**:
  - Verificações básicas (trailing whitespace, end of file)
  - Formatação (Black, isort)
  - Linting (flake8, pylint)
  - Type checking (mypy)
  - Segurança (bandit, safety)
  - Verificações de arquivos (YAML, JSON, Dockerfile)

#### `.pylintrc`
- **Finalidade**: Configuração detalhada do Pylint
- **Configurações**: Plugins, mensagens desabilitadas, limites de complexidade

#### `mypy.ini`
- **Finalidade**: Configuração do MyPy para verificação de tipos
- **Configurações**: Strictness, imports ignorados, configurações por módulo

#### `pytest.ini`
- **Finalidade**: Configuração do pytest para testes
- **Configurações**: Marcadores, cobertura, logging, filtros de warnings

#### `.coveragerc`
- **Finalidade**: Configuração da cobertura de código
- **Configurações**: Arquivos incluídos/excluídos, relatórios, limites

### Arquivos de Desenvolvimento

#### `.editorconfig`
- **Finalidade**: Configurações de editor para consistência de formatação
- **Configurações**: Indentação, charset, line endings por tipo de arquivo

#### `.gitignore`
- **Finalidade**: Arquivos e diretórios ignorados pelo Git
- **Inclui**: Cache Python, logs, uploads, dados temporários, IDEs

#### `.dockerignore`
- **Finalidade**: Arquivos ignorados durante build Docker
- **Inclui**: Documentação, testes, cache, arquivos de desenvolvimento

### Arquivos de VS Code

#### `.vscode/settings.json`
- **Finalidade**: Configurações específicas do VS Code
- **Configurações**: Python interpreter, formatação, linting, extensões

#### `.vscode/launch.json`
- **Finalidade**: Configurações de debug do VS Code
- **Configurações de debug**:
  - FastAPI server
  - Streamlit dashboard
  - Celery worker/beat
  - Pytest
  - Alembic
  - Docker attach

#### `.vscode/tasks.json`
- **Finalidade**: Tasks automatizadas do VS Code
- **Tasks incluídas**:
  - Instalação de dependências
  - Execução de serviços
  - Testes
  - Formatação e linting
  - Docker operations
  - Database migrations

#### `.vscode/extensions.json`
- **Finalidade**: Extensões recomendadas do VS Code
- **Categorias**:
  - Python development
  - Testing
  - Database
  - Docker
  - Git
  - Documentation
  - Productivity

### Arquivos de Banco de Dados

#### `alembic.ini`
- **Finalidade**: Configuração do Alembic para migrações
- **Configurações**: Scripts location, database URL, logging

#### `alembic/env.py`
- **Finalidade**: Ambiente de execução das migrações
- **Configurações**: Conexão com banco, modelos, migrações online/offline

### Arquivos de Deploy

#### `Dockerfile`
- **Finalidade**: Build de imagens Docker multi-stage
- **Stages**: base, development, production, streamlit, worker, beat

#### `docker-compose.yml`
- **Finalidade**: Orquestração de serviços
- **Serviços**: PostgreSQL, Redis, API, Dashboard, Workers, Monitoring

#### `Makefile`
- **Finalidade**: Automação de tarefas de desenvolvimento
- **Comandos**: install, test, lint, format, docker, database, deploy

### Arquivos de CI/CD

#### `.github/workflows/ci.yml`
- **Finalidade**: Pipeline de CI/CD no GitHub Actions
- **Jobs**: tests, quality, security, build, deploy

## 🔧 Como Usar as Configurações

### Setup Inicial

```bash
# 1. Copiar variáveis de ambiente
cp .env.example .env

# 2. Instalar dependências
make install-dev

# 3. Configurar pre-commit
pre-commit install

# 4. Inicializar banco
make db-init
```

### Desenvolvimento

```bash
# Formatação automática
make format

# Verificações de qualidade
make lint
make type-check
make security-check

# Testes
make test
make test-cov

# Executar todas as verificações
make check
```

### VS Code

1. Abra o projeto no VS Code
2. Instale as extensões recomendadas
3. Use F5 para debug ou Ctrl+Shift+P > "Tasks" para executar tasks
4. As configurações de formatação e linting são aplicadas automaticamente

### Docker

```bash
# Desenvolvimento
docker-compose up -d

# Produção
docker-compose -f docker-compose.prod.yml up -d

# Build específico
docker build --target production -t streamleads:prod .
```

## 📊 Métricas de Qualidade

### Cobertura de Código
- **Mínimo**: 80%
- **Relatórios**: Terminal, HTML (htmlcov/), XML (coverage.xml)
- **Exclusões**: Testes, migrações, configurações

### Linting
- **Flake8**: Estilo de código, complexidade
- **Pylint**: Análise estática avançada
- **MyPy**: Verificação de tipos
- **Bandit**: Análise de segurança

### Formatação
- **Black**: Formatação automática de código
- **isort**: Organização de imports
- **Line length**: 88 caracteres
- **Target**: Python 3.11+

## 🔒 Segurança

### Verificações Automáticas
- **Bandit**: Vulnerabilidades no código
- **Safety**: Vulnerabilidades em dependências
- **Pre-commit**: Verificação de secrets

### Variáveis Sensíveis
- Nunca commitar arquivos `.env`
- Usar `.env.example` como template
- Configurar secrets no CI/CD

## 🚀 Deploy

### Ambientes
- **Development**: docker-compose.yml
- **Production**: docker-compose.prod.yml
- **CI/CD**: GitHub Actions

### Configurações por Ambiente
- **Development**: DEBUG=true, logs verbosos
- **Production**: DEBUG=false, otimizações, monitoring

## 📝 Manutenção

### Atualizações
- **Dependências**: `make update`
- **Pre-commit hooks**: `pre-commit autoupdate`
- **Configurações**: Revisar periodicamente

### Monitoramento
- **Logs**: Configurados via loguru
- **Métricas**: Prometheus + Grafana
- **Health checks**: Endpoints dedicados

## 🤝 Contribuição

### Antes de Contribuir
1. Execute `make check` para verificar qualidade
2. Certifique-se que os testes passam
3. Mantenha cobertura acima de 80%
4. Siga as convenções de commit

### Adicionando Configurações
1. Documente a finalidade
2. Adicione ao `.gitignore` se necessário
3. Atualize este documento
4. Teste em ambiente limpo

---

**Nota**: Este documento deve ser atualizado sempre que novas configurações forem adicionadas ou modificadas.