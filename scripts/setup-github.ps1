# =============================================================================
# SCRIPT DE CONFIGURAÇÃO DO GITHUB - STREAMLEADS (PowerShell)
# =============================================================================
# Este script automatiza a configuração inicial do GitHub para o projeto

[CmdletBinding()]
param(
    [switch]$GitOnly,
    [switch]$Help
)

# Configurações
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Variáveis globais
$script:GhCliAvailable = $false
$script:RepoUrl = ""

# Função para log colorido
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    switch ($Level) {
        "Success" { Write-Host "[$timestamp] ✅ $Message" -ForegroundColor Green }
        "Warning" { Write-Host "[$timestamp] ⚠️  $Message" -ForegroundColor Yellow }
        "Error"   { Write-Host "[$timestamp] ❌ $Message" -ForegroundColor Red }
        "Info"    { Write-Host "[$timestamp] ℹ️  $Message" -ForegroundColor Cyan }
        default   { Write-Host "[$timestamp] $Message" -ForegroundColor Blue }
    }
}

# Função para mostrar banner
function Show-Banner {
    Write-Host "" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "                🐙 STREAMLEADS GITHUB SETUP                   " -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
}

# Função para mostrar ajuda
function Show-Help {
    Write-Host "Uso: .\setup-github.ps1 [opções]" -ForegroundColor White
    Write-Host ""
    Write-Host "Opções:" -ForegroundColor White
    Write-Host "  -Help         Mostra esta ajuda" -ForegroundColor Gray
    Write-Host "  -GitOnly      Configura apenas Git (sem GitHub)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Exemplos:" -ForegroundColor White
    Write-Host "  .\setup-github.ps1                # Setup completo" -ForegroundColor Gray
    Write-Host "  .\setup-github.ps1 -GitOnly       # Apenas Git" -ForegroundColor Gray
    Write-Host ""
}

# Função para verificar pré-requisitos
function Test-Prerequisites {
    Write-Log "Verificando pré-requisitos..."
    
    # Verificar Git
    try {
        $gitVersion = git --version 2>$null
        if ($gitVersion) {
            Write-Log "Git encontrado: $gitVersion" "Success"
        } else {
            throw "Git não encontrado"
        }
    }
    catch {
        Write-Log "Git não encontrado! Instale o Git primeiro." "Error"
        Write-Log "Download: https://git-scm.com/download/windows" "Info"
        exit 1
    }
    
    # Verificar GitHub CLI (opcional)
    try {
        $ghVersion = gh --version 2>$null
        if ($ghVersion) {
            $script:GhCliAvailable = $true
            Write-Log "GitHub CLI encontrado!" "Success"
        } else {
            throw "GitHub CLI não encontrado"
        }
    }
    catch {
        $script:GhCliAvailable = $false
        Write-Log "GitHub CLI não encontrado. Algumas funcionalidades serão limitadas." "Warning"
        Write-Log "Instale com: winget install GitHub.cli" "Info"
    }
    
    # Verificar se está no diretório correto
    if (-not (Test-Path "README.md") -or -not (Test-Path "docker-compose.yml")) {
        Write-Log "Execute este script no diretório raiz do projeto StreamLeads!" "Error"
        exit 1
    }
    
    Write-Log "Pré-requisitos verificados!" "Success"
}

# Função para configurar Git
function Set-GitConfig {
    Write-Log "Configurando Git..."
    
    # Verificar se já é um repositório Git
    if (-not (Test-Path ".git")) {
        Write-Log "Inicializando repositório Git..."
        git init
        Write-Log "Repositório Git inicializado!" "Success"
    }
    else {
        Write-Log "Repositório Git já existe." "Info"
    }
    
    # Configurar usuário se não estiver configurado
    try {
        $gitName = git config user.name 2>$null
        if (-not $gitName) {
            $gitName = Read-Host "Nome do usuário Git"
            git config user.name "$gitName"
        }
    }
    catch {
        $gitName = Read-Host "Nome do usuário Git"
        git config user.name "$gitName"
    }
    
    try {
        $gitEmail = git config user.email 2>$null
        if (-not $gitEmail) {
            $gitEmail = Read-Host "Email do usuário Git"
            git config user.email "$gitEmail"
        }
    }
    catch {
        $gitEmail = Read-Host "Email do usuário Git"
        git config user.email "$gitEmail"
    }
    
    Write-Log "Git configurado!" "Success"
    $userName = git config user.name
    $userEmail = git config user.email
    Write-Log "Usuário: $userName <$userEmail>" "Info"
}

# Função para configurar .gitignore
function Set-GitIgnore {
    Write-Log "Configurando .gitignore..."
    
    if (-not (Test-Path ".gitignore")) {
        $gitignoreContent = @'
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

# Windows
Desktop.ini
$RECYCLE.BIN/
*.cab
*.msi
*.msix
*.msm
*.msp
*.lnk

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
'@
        
        $gitignoreContent | Out-File -FilePath ".gitignore" -Encoding UTF8
        Write-Log ".gitignore criado!" "Success"
    }
    else {
        Write-Log ".gitignore já existe." "Info"
    }
}

# Função para fazer commit inicial
function Invoke-InitialCommit {
    Write-Log "Fazendo commit inicial..."
    
    # Adicionar todos os arquivos
    git add .
    
    # Verificar se há mudanças para commit
    $gitStatus = git status --porcelain
    if (-not $gitStatus) {
        Write-Log "Nenhuma mudança para commit." "Info"
        return
    }
    
    # Fazer commit
    $commitMessage = "feat: initial commit - StreamLeads setup`n`n- Configuração inicial do projeto`n- Docker e Docker Compose configurados`n- CI/CD pipeline configurado`n- Documentação básica`n- Scripts de automação"
    
    git commit -m $commitMessage
    Write-Log "Commit inicial realizado!" "Success"
}

# Função para configurar repositório GitHub manualmente
function Set-GitHubManual {
    Write-Log "Configuração manual do GitHub..." "Warning"
    Write-Host ""
    Write-Host "1. Acesse https://github.com/new" -ForegroundColor Cyan
    Write-Host "2. Crie um repositório chamado 'streamleads'" -ForegroundColor Cyan
    Write-Host "3. Não inicialize com README, .gitignore ou licença" -ForegroundColor Yellow
    Write-Host ""
    
    $continue = Read-Host "Pressione Enter após criar o repositório..."
    
    $repoUrl = Read-Host "URL do repositório (ex: https://github.com/usuario/streamleads.git)"
    if ($repoUrl) {
        try {
            git remote add origin $repoUrl 2>$null
        }
        catch {
            git remote set-url origin $repoUrl
        }
        Write-Log "Remote origin configurado!" "Success"
        
        # Push inicial
        try {
            git push -u origin main
            Write-Log "Código enviado para o GitHub!" "Success"
        }
        catch {
            Write-Log "Erro ao enviar código. Verifique as credenciais." "Error"
        }
    }
}

# Função para mostrar próximos passos
function Show-NextSteps {
    Write-Host ""
    Write-Log "🎉 Configuração concluída!" "Success"
    Write-Host ""
    Write-Log "📋 Próximos passos:" "Info"
    Write-Host ""
    Write-Host "1. ✅ Configure os secrets no GitHub" -ForegroundColor White
    Write-Host "2. ✅ Configure seu servidor de produção" -ForegroundColor White
    Write-Host "3. ✅ Teste o workflow de CI/CD" -ForegroundColor White
    Write-Host "4. ✅ Configure monitoramento" -ForegroundColor White
    Write-Host "5. ✅ Faça sua primeira release" -ForegroundColor White
    Write-Host ""
    Write-Host "📚 Documentação:" -ForegroundColor Cyan
    Write-Host "  - README-DEPLOY.md: Guia completo de deploy" -ForegroundColor Gray
    Write-Host "  - documentacao/: Documentação técnica" -ForegroundColor Gray
    Write-Host ""
}

# Função principal
function Invoke-Main {
    Show-Banner
    
    Write-Log "Iniciando configuração do GitHub para StreamLeads..."
    
    Test-Prerequisites
    Set-GitConfig
    Set-GitIgnore
    Invoke-InitialCommit
    
    # Configurar GitHub
    if ($script:GhCliAvailable) {
        $useGhCli = Read-Host "Usar GitHub CLI para criar repositório? (Y/n)"
        if ($useGhCli -notmatch "^[Nn]$") {
            try {
                # Verificar login
                gh auth status 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Log "Fazendo login no GitHub..."
                    gh auth login
                }
                
                # Criar repositório
                $repoName = Read-Host "Nome do repositório [streamleads]"
                if (-not $repoName) { $repoName = "streamleads" }
                
                $repoDescription = Read-Host "Descrição [Sistema de gestão e automação de leads]"
                if (-not $repoDescription) { $repoDescription = "Sistema de gestão e automação de leads" }
                
                $isPublic = Read-Host "Repositório público? (y/N)"
                $visibility = if ($isPublic -match "^[Yy]$") { "--public" } else { "--private" }
                
                gh repo create $repoName --description $repoDescription $visibility --source=. --remote=origin --push
                Write-Log "Repositório criado e código enviado!" "Success"
                
                $script:RepoUrl = gh repo view --json url --jq .url
                Write-Log "URL: $($script:RepoUrl)" "Info"
            }
            catch {
                Write-Log "Erro ao usar GitHub CLI. Configurando manualmente..." "Warning"
                Set-GitHubManual
            }
        }
        else {
            Set-GitHubManual
        }
    }
    else {
        Set-GitHubManual
    }
    
    Show-NextSteps
}

# Função para configuração apenas do Git
function Invoke-GitOnly {
    Show-Banner
    Test-Prerequisites
    Set-GitConfig
    Set-GitIgnore
    Invoke-InitialCommit
    Write-Log "Git configurado!" "Success"
}

# Verificar argumentos e executar
if ($Help) {
    Show-Help
    exit 0
}
elseif ($GitOnly) {
    Invoke-GitOnly
}
else {
    Invoke-Main
}