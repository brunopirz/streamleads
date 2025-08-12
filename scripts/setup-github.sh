#!/bin/bash

# =============================================================================
# SCRIPT DE CONFIGURAÇÃO DO GITHUB - STREAMLEADS
# =============================================================================
# Este script automatiza a configuração inicial do GitHub para o projeto

set -e  # Sair em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Função para log
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"
}

log_info() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')] ℹ️  $1${NC}"
}

# Função para mostrar banner
show_banner() {
    echo -e "${PURPLE}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "                🐙 STREAMLEADS GITHUB SETUP                   "
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

# Função para verificar pré-requisitos
check_prerequisites() {
    log "Verificando pré-requisitos..."
    
    # Verificar Git
    if ! command -v git >/dev/null 2>&1; then
        log_error "Git não encontrado! Instale o Git primeiro."
        exit 1
    fi
    
    # Verificar GitHub CLI (opcional)
    if command -v gh >/dev/null 2>&1; then
        GH_CLI_AVAILABLE=true
        log_success "GitHub CLI encontrado!"
    else
        GH_CLI_AVAILABLE=false
        log_warning "GitHub CLI não encontrado. Algumas funcionalidades serão limitadas."
        log_info "Instale com: https://cli.github.com/"
    fi
    
    # Verificar se está no diretório correto
    if [ ! -f "README.md" ] || [ ! -f "docker-compose.yml" ]; then
        log_error "Execute este script no diretório raiz do projeto StreamLeads!"
        exit 1
    fi
    
    log_success "Pré-requisitos verificados!"
}

# Função para configurar Git
setup_git() {
    log "Configurando Git..."
    
    # Verificar se já é um repositório Git
    if [ ! -d ".git" ]; then
        log "Inicializando repositório Git..."
        git init
        log_success "Repositório Git inicializado!"
    else
        log_info "Repositório Git já existe."
    fi
    
    # Configurar usuário se não estiver configurado
    if [ -z "$(git config user.name)" ]; then
        read -p "Nome do usuário Git: " git_name
        git config user.name "$git_name"
    fi
    
    if [ -z "$(git config user.email)" ]; then
        read -p "Email do usuário Git: " git_email
        git config user.email "$git_email"
    fi
    
    log_success "Git configurado!"
    log_info "Usuário: $(git config user.name) <$(git config user.email)>"
}

# Função para configurar .gitignore
setup_gitignore() {
    log "Configurando .gitignore..."
    
    if [ ! -f ".gitignore" ]; then
        cat > .gitignore << 'EOF'
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# C extensions
*.so

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# PyInstaller
*.manifest
*.spec

# Installer logs
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage reports
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.py,cover
.hypothesis/
.pytest_cache/
cover/

# Translations
*.mo
*.pot

# Django stuff:
*.log
local_settings.py
db.sqlite3
db.sqlite3-journal

# Flask stuff:
instance/
.webassets-cache

# Scrapy stuff:
.scrapy

# Sphinx documentation
docs/_build/

# PyBuilder
.pybuilder/
target/

# Jupyter Notebook
.ipynb_checkpoints

# IPython
profile_default/
ipython_config.py

# pyenv
.python-version

# pipenv
Pipfile.lock

# poetry
poetry.lock

# pdm
.pdm.toml

# PEP 582
__pypackages__/

# Celery stuff
celerybeat-schedule
celerybeat.pid

# SageMath parsed files
*.sage.py

# Environments
.env
.env.*
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# Spyder project settings
.spyderproject
.spyproject

# Rope project settings
.ropeproject

# mkdocs documentation
/site

# mypy
.mypy_cache/
.dmypy.json
dmypy.json

# Pyre type checker
.pyre/

# pytype static type analyzer
.pytype/

# Cython debug symbols
cython_debug/

# PyCharm
.idea/

# VS Code
.vscode/
!.vscode/settings.json
!.vscode/tasks.json
!.vscode/launch.json
!.vscode/extensions.json

# Docker
.dockerignore

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# StreamLeads specific
backups/
logs/
*.log
data/
uploads/
static/uploads/
media/

# Temporary files
*.tmp
*.temp
*.swp
*.swo
*~

# Database
*.db
*.sqlite
*.sqlite3

# Certificates
*.pem
*.key
*.crt
*.p12

# Secrets
secrets/
.secrets
EOF
        log_success ".gitignore criado!"
    else
        log_info ".gitignore já existe."
    fi
}

# Função para criar repositório no GitHub
create_github_repo() {
    if [ "$GH_CLI_AVAILABLE" = true ]; then
        log "Criando repositório no GitHub..."
        
        # Verificar se já está logado
        if ! gh auth status >/dev/null 2>&1; then
            log "Fazendo login no GitHub..."
            gh auth login
        fi
        
        # Obter informações do repositório
        read -p "Nome do repositório [streamleads]: " repo_name
        repo_name=${repo_name:-streamleads}
        
        read -p "Descrição: " repo_description
        repo_description=${repo_description:-"Sistema de gestão e automação de leads"}
        
        read -p "Repositório público? (y/N): " is_public
        if [[ $is_public =~ ^[Yy]$ ]]; then
            visibility="--public"
        else
            visibility="--private"
        fi
        
        # Criar repositório
        if gh repo create "$repo_name" --description "$repo_description" $visibility --source=. --remote=origin --push; then
            log_success "Repositório criado e código enviado!"
            REPO_URL=$(gh repo view --json url --jq .url)
            log_info "URL: $REPO_URL"
        else
            log_error "Falha ao criar repositório."
            return 1
        fi
    else
        log_warning "GitHub CLI não disponível. Crie o repositório manualmente:"
        echo "1. Acesse https://github.com/new"
        echo "2. Crie um repositório chamado 'streamleads'"
        echo "3. Execute os comandos mostrados no GitHub"
        echo ""
        read -p "Pressione Enter após criar o repositório..."
        
        read -p "URL do repositório (ex: https://github.com/usuario/streamleads.git): " repo_url
        if [ -n "$repo_url" ]; then
            git remote add origin "$repo_url" 2>/dev/null || git remote set-url origin "$repo_url"
            log_success "Remote origin configurado!"
        fi
    fi
}

# Função para configurar branches
setup_branches() {
    log "Configurando branches..."
    
    # Renomear branch principal para main se necessário
    current_branch=$(git branch --show-current)
    if [ "$current_branch" = "master" ]; then
        git branch -m main
        log_info "Branch renomeada de master para main"
    fi
    
    # Criar branch develop
    if ! git show-ref --verify --quiet refs/heads/develop; then
        git checkout -b develop
        git checkout main
        log_success "Branch develop criada!"
    else
        log_info "Branch develop já existe."
    fi
    
    log_success "Branches configuradas!"
}

# Função para configurar GitHub Actions
setup_github_actions() {
    log "Configurando GitHub Actions..."
    
    # Criar diretório se não existir
    mkdir -p .github/workflows
    
    # Verificar se o arquivo CI/CD já existe
    if [ -f ".github/workflows/ci-cd.yml" ]; then
        log_info "Workflow CI/CD já existe."
    else
        log_warning "Workflow CI/CD não encontrado. Execute o setup completo primeiro."
    fi
    
    # Criar arquivo de configuração do Dependabot
    if [ ! -f ".github/dependabot.yml" ]; then
        cat > .github/dependabot.yml << 'EOF'
version: 2
updates:
  # Python dependencies
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
    
  # Docker dependencies
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    
  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
EOF
        log_success "Dependabot configurado!"
    fi
    
    # Criar templates de issues e PRs
    mkdir -p .github/ISSUE_TEMPLATE
    
    if [ ! -f ".github/ISSUE_TEMPLATE/bug_report.md" ]; then
        cat > .github/ISSUE_TEMPLATE/bug_report.md << 'EOF'
---
name: Bug Report
about: Relatar um bug
title: '[BUG] '
labels: bug
assignees: ''
---

## Descrição do Bug
Descreva claramente o bug encontrado.

## Passos para Reproduzir
1. Vá para '...'
2. Clique em '....'
3. Role para baixo até '....'
4. Veja o erro

## Comportamento Esperado
Descreva o que deveria acontecer.

## Screenshots
Se aplicável, adicione screenshots.

## Ambiente
- OS: [ex: Ubuntu 20.04]
- Browser: [ex: Chrome 91]
- Versão: [ex: v1.0.0]

## Informações Adicionais
Adicione qualquer outra informação relevante.
EOF
    fi
    
    if [ ! -f ".github/ISSUE_TEMPLATE/feature_request.md" ]; then
        cat > .github/ISSUE_TEMPLATE/feature_request.md << 'EOF'
---
name: Feature Request
about: Sugerir uma nova funcionalidade
title: '[FEATURE] '
labels: enhancement
assignees: ''
---

## Descrição da Funcionalidade
Descreva claramente a funcionalidade desejada.

## Problema que Resolve
Descreva o problema que esta funcionalidade resolveria.

## Solução Proposta
Descreva como você gostaria que funcionasse.

## Alternativas Consideradas
Descreva outras soluções que você considerou.

## Informações Adicionais
Adicione qualquer outra informação relevante.
EOF
    fi
    
    if [ ! -f ".github/pull_request_template.md" ]; then
        cat > .github/pull_request_template.md << 'EOF'
## Descrição
Descreva as mudanças realizadas neste PR.

## Tipo de Mudança
- [ ] Bug fix
- [ ] Nova funcionalidade
- [ ] Breaking change
- [ ] Documentação
- [ ] Refatoração
- [ ] Testes

## Como Testar
Descreva como testar as mudanças.

## Checklist
- [ ] Código segue os padrões do projeto
- [ ] Testes foram adicionados/atualizados
- [ ] Documentação foi atualizada
- [ ] Todas as verificações passaram
- [ ] PR foi testado localmente

## Screenshots (se aplicável)
Adicione screenshots das mudanças visuais.

## Issues Relacionadas
Fecha #(número da issue)
EOF
    fi
    
    log_success "Templates do GitHub configurados!"
}

# Função para fazer commit inicial
initial_commit() {
    log "Fazendo commit inicial..."
    
    # Adicionar todos os arquivos
    git add .
    
    # Verificar se há mudanças para commit
    if git diff --staged --quiet; then
        log_info "Nenhuma mudança para commit."
        return 0
    fi
    
    # Fazer commit
    git commit -m "feat: initial commit - StreamLeads setup

- Configuração inicial do projeto
- Docker e Docker Compose configurados
- CI/CD pipeline configurado
- Documentação básica
- Scripts de automação"
    
    log_success "Commit inicial realizado!"
}

# Função para push inicial
initial_push() {
    log "Enviando código para o GitHub..."
    
    # Verificar se remote origin existe
    if ! git remote get-url origin >/dev/null 2>&1; then
        log_error "Remote origin não configurado!"
        return 1
    fi
    
    # Push da branch main
    if git push -u origin main; then
        log_success "Branch main enviada!"
    else
        log_error "Falha ao enviar branch main."
        return 1
    fi
    
    # Push da branch develop
    if git show-ref --verify --quiet refs/heads/develop; then
        git push -u origin develop
        log_success "Branch develop enviada!"
    fi
}

# Função para configurar secrets (informativo)
show_secrets_info() {
    log_info "Configuração de Secrets no GitHub:"
    echo ""
    echo "Acesse: https://github.com/$(git config remote.origin.url | sed 's/.*github.com[:\/]//; s/.git$//')/settings/secrets/actions"
    echo ""
    echo "Adicione os seguintes secrets:"
    echo ""
    echo "📋 STAGING:"
    echo "  STAGING_HOST=seu-servidor-staging.com"
    echo "  STAGING_USER=deploy"
    echo "  STAGING_SSH_KEY=sua-chave-ssh-privada"
    echo "  STAGING_PORT=22"
    echo ""
    echo "📋 PRODUÇÃO:"
    echo "  PRODUCTION_HOST=seu-servidor.com"
    echo "  PRODUCTION_USER=deploy"
    echo "  PRODUCTION_SSH_KEY=sua-chave-ssh-privada"
    echo "  PRODUCTION_PORT=22"
    echo ""
    echo "📋 NOTIFICAÇÕES:"
    echo "  SLACK_WEBHOOK_URL=https://hooks.slack.com/services/..."
    echo "  DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/..."
    echo ""
}

# Função para mostrar próximos passos
show_next_steps() {
    echo ""
    log_success "🎉 GitHub configurado com sucesso!"
    echo ""
    log_info "📋 Próximos passos:"
    echo ""
    echo "1. ✅ Configure os secrets no GitHub (mostrados acima)"
    echo "2. ✅ Configure seu servidor de produção"
    echo "3. ✅ Teste o workflow de CI/CD"
    echo "4. ✅ Configure monitoramento"
    echo "5. ✅ Faça sua primeira release"
    echo ""
    echo "📚 Documentação:"
    echo "  - README-DEPLOY.md: Guia completo de deploy"
    echo "  - documentacao/: Documentação técnica"
    echo ""
    echo "🔗 Links úteis:"
    if [ -n "$REPO_URL" ]; then
        echo "  - Repositório: $REPO_URL"
        echo "  - Actions: $REPO_URL/actions"
        echo "  - Settings: $REPO_URL/settings"
    fi
    echo ""
}

# Função principal
main() {
    show_banner
    
    log "Iniciando configuração do GitHub para StreamLeads..."
    
    check_prerequisites
    setup_git
    setup_gitignore
    setup_branches
    setup_github_actions
    initial_commit
    
    # Perguntar se deve criar repositório
    if [ "$GH_CLI_AVAILABLE" = true ]; then
        read -p "Criar repositório no GitHub? (Y/n): " create_repo
        if [[ ! $create_repo =~ ^[Nn]$ ]]; then
            create_github_repo
            initial_push
        fi
    else
        read -p "Configurar remote origin manualmente? (Y/n): " setup_remote
        if [[ ! $setup_remote =~ ^[Nn]$ ]]; then
            create_github_repo
            initial_push
        fi
    fi
    
    show_secrets_info
    show_next_steps
}

# Verificar argumentos
case "${1:-}" in
    "--help" | "-h")
        echo "Uso: $0 [opções]"
        echo ""
        echo "Opções:"
        echo "  --help, -h    Mostra esta ajuda"
        echo "  --git-only    Configura apenas Git (sem GitHub)"
        echo ""
        exit 0
        ;;
    "--git-only")
        show_banner
        check_prerequisites
        setup_git
        setup_gitignore
        setup_branches
        initial_commit
        log_success "Git configurado!"
        ;;
    "")
        main
        ;;
    *)
        log_error "Opção inválida: $1"
        echo "Use --help para ver as opções disponíveis."
        exit 1
        ;;
esac