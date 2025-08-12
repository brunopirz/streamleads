# StreamLeads - Script de Configuração para Portainer (PowerShell)
# Este script automatiza a configuração inicial do StreamLeads no Portainer

param(
    [Parameter(Position=0)]
    [ValidateSet('interactive', 'env', 'check', 'create', 'help')]
    [string]$Command = 'interactive',
    
    [Parameter(Position=1)]
    [string]$PortainerUrl,
    
    [Parameter(Position=2)]
    [string]$PortainerToken,
    
    [Parameter(Position=3)]
    [string]$EndpointId = '1'
)

# Configurações
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Funções de logging
function Write-Log {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" -ForegroundColor Green
}

function Write-Warning-Log {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] WARNING: $Message" -ForegroundColor Yellow
}

function Write-Error-Log {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR: $Message" -ForegroundColor Red
    exit 1
}

function Write-Info {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] INFO: $Message" -ForegroundColor Blue
}

# Verificar se está executando como administrador
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Verificar dependências
function Test-Dependencies {
    Write-Log "Verificando dependências..."
    
    $dependencies = @('curl', 'docker')
    $missingDeps = @()
    
    foreach ($dep in $dependencies) {
        try {
            $null = Get-Command $dep -ErrorAction Stop
        }
        catch {
            $missingDeps += $dep
        }
    }
    
    if ($missingDeps.Count -gt 0) {
        Write-Error-Log "Dependências não encontradas: $($missingDeps -join ', ')"
    }
    
    # Verificar se o PowerShell tem suporte a ConvertTo-Json
    try {
        $null = @{} | ConvertTo-Json -ErrorAction Stop
    }
    catch {
        Write-Error-Log "PowerShell não suporta ConvertTo-Json. Atualize para uma versão mais recente."
    }
    
    Write-Log "Todas as dependências estão instaladas"
}

# Gerar chave secreta
function New-SecretKey {
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    return [System.BitConverter]::ToString($bytes) -replace '-', ''
}

# Gerar senha segura
function New-SecurePassword {
    $bytes = New-Object byte[] 24
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    return [System.Convert]::ToBase64String($bytes)
}

# Configurar variáveis de ambiente
function Set-Environment {
    Write-Log "Configurando variáveis de ambiente..."
    
    $envFile = ".env.portainer"
    
    # Verificar se já existe
    if (Test-Path $envFile) {
        Write-Warning-Log "Arquivo $envFile já existe"
        $response = Read-Host "Sobrescrever? (y/N)"
        if ($response -notmatch '^[Yy]$') {
            Write-Info "Usando arquivo existente: $envFile"
            return
        }
    }
    
    # Gerar configurações
    $secretKey = New-SecretKey
    $dbPassword = New-SecurePassword
    $grafanaPassword = New-SecurePassword
    
    $envContent = @"
# StreamLeads - Configuração para Portainer
# Gerado automaticamente em $(Get-Date)

# Configurações da Aplicação
APP_NAME=StreamLeads
APP_ENV=production
DEBUG=false
SECRET_KEY=$secretKey

# Configurações do Banco de Dados
POSTGRES_DB=streamleads
POSTGRES_USER=streamleads
POSTGRES_PASSWORD=$dbPassword
DATABASE_URL=postgresql://streamleads:$dbPassword@db:5432/streamleads

# Configurações Redis
REDIS_URL=redis://redis:6379/0

# Configurações de Email (configure conforme necessário)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=
SMTP_PASSWORD=
SMTP_FROM=

# Configurações de Integração (configure conforme necessário)
WHATSAPP_API_TOKEN=
TELEGRAM_BOT_TOKEN=

# Configurações de Monitoramento
SENTRY_DSN=

# Configurações de Backup
BACKUP_SCHEDULE=0 2 * * *

# Configurações do Grafana
GRAFANA_PASSWORD=$grafanaPassword
"@
    
    $envContent | Out-File -FilePath $envFile -Encoding UTF8
    
    Write-Log "Arquivo de configuração criado: $envFile"
    Write-Info "Senha do banco de dados: $dbPassword"
    Write-Info "Senha do Grafana: $grafanaPassword"
    Write-Warning-Log "IMPORTANTE: Guarde essas senhas em local seguro!"
}

# Verificar conectividade com Portainer
function Test-PortainerConnection {
    param(
        [string]$Url,
        [string]$Token
    )
    
    if ([string]::IsNullOrEmpty($Url) -or [string]::IsNullOrEmpty($Token)) {
        Write-Warning-Log "URL ou token do Portainer não fornecidos"
        return $false
    }
    
    Write-Log "Verificando conectividade com Portainer..."
    
    try {
        $headers = @{
            'Authorization' = "Bearer $Token"
        }
        
        $response = Invoke-RestMethod -Uri "$Url/api/endpoints" -Headers $headers -Method Get -TimeoutSec 30
        Write-Log "Conectividade com Portainer OK"
        return $true
    }
    catch {
        Write-Error-Log "Falha na conectividade com Portainer: $($_.Exception.Message)"
        return $false
    }
}

# Criar stack no Portainer via API
function New-PortainerStack {
    param(
        [string]$Url,
        [string]$Token,
        [string]$EndpointId
    )
    
    if ([string]::IsNullOrEmpty($Url) -or [string]::IsNullOrEmpty($Token) -or [string]::IsNullOrEmpty($EndpointId)) {
        Write-Error-Log "Parâmetros obrigatórios não fornecidos para criação da stack"
    }
    
    Write-Log "Criando stack StreamLeads no Portainer..."
    
    # Ler variáveis de ambiente
    $envVars = @()
    $envFile = ".env.portainer"
    
    if (Test-Path $envFile) {
        $envContent = Get-Content $envFile
        foreach ($line in $envContent) {
            # Ignorar comentários e linhas vazias
            if ($line -match '^#' -or [string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            
            if ($line -match '^([^=]+)=(.*)$') {
                $envVars += @{
                    name = $matches[1]
                    value = $matches[2]
                }
            }
        }
    }
    
    # Payload para criação da stack
    $payload = @{
        name = "streamleads"
        repositoryURL = "https://github.com/brunopirz/streamleads"
        repositoryReferenceName = "main"
        composeFile = "docker-compose.portainer.yml"
        env = $envVars
    } | ConvertTo-Json -Depth 10
    
    try {
        $headers = @{
            'Authorization' = "Bearer $Token"
            'Content-Type' = 'application/json'
        }
        
        $uri = "$Url/api/stacks?type=2&method=repository&endpointId=$EndpointId"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -Body $payload -TimeoutSec 60
        
        Write-Log "Stack StreamLeads criada com sucesso!"
        Write-Info "ID da Stack: $($response.Id)"
    }
    catch {
        Write-Error-Log "Falha ao criar stack: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Host "Resposta do servidor: $responseBody" -ForegroundColor Red
        }
    }
}

# Exibir informações de acesso
function Show-AccessInfo {
    Write-Log "Configuração concluída!"
    Write-Host ""
    Write-Info "Informações de Acesso:"
    Write-Host "  📊 Dashboard: http://seu-servidor:8501"
    Write-Host "  🔌 API: http://seu-servidor:8000"
    Write-Host "  📚 Documentação API: http://seu-servidor:8000/docs"
    Write-Host "  🌐 Nginx: http://seu-servidor (se configurado)"
    Write-Host "  📈 Prometheus: http://seu-servidor:9090 (se habilitado)"
    Write-Host "  📊 Grafana: http://seu-servidor:3000 (se habilitado)"
    Write-Host ""
    Write-Info "Próximos passos:"
    Write-Host "  1. Aguarde o download e inicialização dos containers"
    Write-Host "  2. Verifique os logs no Portainer"
    Write-Host "  3. Acesse o dashboard para configurar leads"
    Write-Host "  4. Configure integrações (WhatsApp, Telegram, Email)"
    Write-Host ""
    Write-Warning-Log "Lembre-se de:"
    Write-Host "  - Configurar SSL/HTTPS para produção"
    Write-Host "  - Fazer backup regular dos dados"
    Write-Host "  - Monitorar logs e métricas"
    Write-Host "  - Atualizar senhas padrão"
}

# Menu interativo
function Start-InteractiveSetup {
    Write-Host ""
    Write-Info "=== StreamLeads - Configuração para Portainer ==="
    Write-Host ""
    
    # Configurar ambiente
    Set-Environment
    
    Write-Host ""
    $response = Read-Host "Deseja criar a stack automaticamente via API do Portainer? (y/N)"
    
    if ($response -match '^[Yy]$') {
        Write-Host ""
        $portainerUrl = Read-Host "URL do Portainer (ex: https://portainer.exemplo.com)"
        $portainerToken = Read-Host "Token de acesso do Portainer"
        $endpointId = Read-Host "ID do endpoint (geralmente 1 para local)"
        
        if ([string]::IsNullOrEmpty($endpointId)) {
            $endpointId = "1"
        }
        
        if (Test-PortainerConnection -Url $portainerUrl -Token $portainerToken) {
            New-PortainerStack -Url $portainerUrl -Token $portainerToken -EndpointId $endpointId
        }
    }
    else {
        Write-Info "Stack não criada automaticamente"
        Write-Host "Para criar manualmente:"
        Write-Host "1. Acesse seu Portainer"
        Write-Host "2. Vá em Stacks > Add stack"
        Write-Host "3. Use o repositório: https://github.com/brunopirz/streamleads"
        Write-Host "4. Arquivo: docker-compose.portainer.yml"
        Write-Host "5. Importe as variáveis do arquivo .env.portainer"
    }
    
    Show-AccessInfo
}

# Exibir ajuda
function Show-Help {
    Write-Host "StreamLeads - Setup para Portainer (PowerShell)"
    Write-Host "============================================="
    Write-Host ""
    Write-Host "Uso: .\setup-portainer.ps1 [comando] [argumentos]"
    Write-Host ""
    Write-Host "Comandos:"
    Write-Host "  interactive                           Configuração interativa (padrão)"
    Write-Host "  env                                  Gerar apenas arquivo .env.portainer"
    Write-Host "  check <url> <token>                  Verificar conectividade com Portainer"
    Write-Host "  create <url> <token> [endpoint_id]   Criar stack no Portainer"
    Write-Host "  help                                 Exibir esta ajuda"
    Write-Host ""
    Write-Host "Exemplos:"
    Write-Host "  .\setup-portainer.ps1"
    Write-Host "  .\setup-portainer.ps1 env"
    Write-Host "  .\setup-portainer.ps1 check https://portainer.exemplo.com token123"
    Write-Host "  .\setup-portainer.ps1 create https://portainer.exemplo.com token123 1"
}

# Função principal
function Main {
    Write-Host "🚀 StreamLeads - Setup para Portainer" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    
    # Verificar se está executando como administrador
    if (Test-Administrator) {
        Write-Warning-Log "Este script está sendo executado como administrador"
        $response = Read-Host "Continuar mesmo assim? (y/N)"
        if ($response -notmatch '^[Yy]$') {
            exit 1
        }
    }
    
    Test-Dependencies
    
    # Verificar se estamos no diretório correto
    if (-not (Test-Path "docker-compose.portainer.yml")) {
        Write-Error-Log "Arquivo docker-compose.portainer.yml não encontrado. Execute este script no diretório raiz do projeto."
    }
    
    switch ($Command) {
        'env' {
            Set-Environment
        }
        'check' {
            if ([string]::IsNullOrEmpty($PortainerUrl) -or [string]::IsNullOrEmpty($PortainerToken)) {
                Write-Error-Log "URL e token do Portainer são obrigatórios para o comando 'check'"
            }
            Test-PortainerConnection -Url $PortainerUrl -Token $PortainerToken
        }
        'create' {
            if ([string]::IsNullOrEmpty($PortainerUrl) -or [string]::IsNullOrEmpty($PortainerToken)) {
                Write-Error-Log "URL e token do Portainer são obrigatórios para o comando 'create'"
            }
            New-PortainerStack -Url $PortainerUrl -Token $PortainerToken -EndpointId $EndpointId
        }
        'help' {
            Show-Help
        }
        'interactive' {
            Start-InteractiveSetup
        }
        default {
            Write-Error-Log "Comando inválido: $Command. Use 'help' para ver os comandos disponíveis."
        }
    }
}

# Executar função principal
try {
    Main
}
catch {
    Write-Error-Log "Erro inesperado: $($_.Exception.Message)"
}