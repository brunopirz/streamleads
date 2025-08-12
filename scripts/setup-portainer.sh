#!/bin/bash

# StreamLeads - Script de Configuração para Portainer
# Este script automatiza a configuração inicial do StreamLeads no Portainer

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Verificar se o script está sendo executado como root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        warn "Este script não deve ser executado como root"
        read -p "Continuar mesmo assim? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Verificar dependências
check_dependencies() {
    log "Verificando dependências..."
    
    local deps=("curl" "jq" "docker")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Dependências não encontradas: ${missing_deps[*]}"
    fi
    
    log "Todas as dependências estão instaladas"
}

# Gerar chave secreta
generate_secret_key() {
    openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p -c 32
}

# Gerar senha segura
generate_password() {
    openssl rand -base64 32 2>/dev/null || head -c 24 /dev/urandom | base64
}

# Configurar variáveis de ambiente
setup_environment() {
    log "Configurando variáveis de ambiente..."
    
    # Arquivo de configuração
    local env_file=".env.portainer"
    
    # Verificar se já existe
    if [[ -f "$env_file" ]]; then
        warn "Arquivo $env_file já existe"
        read -p "Sobrescrever? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Usando arquivo existente: $env_file"
            return
        fi
    fi
    
    # Gerar configurações
    local secret_key=$(generate_secret_key)
    local db_password=$(generate_password)
    local grafana_password=$(generate_password)
    
    cat > "$env_file" << EOF
# StreamLeads - Configuração para Portainer
# Gerado automaticamente em $(date)

# Configurações da Aplicação
APP_NAME=StreamLeads
APP_ENV=production
DEBUG=false
SECRET_KEY=$secret_key

# Configurações do Banco de Dados
POSTGRES_DB=streamleads
POSTGRES_USER=streamleads
POSTGRES_PASSWORD=$db_password
DATABASE_URL=postgresql://streamleads:$db_password@db:5432/streamleads

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
GRAFANA_PASSWORD=$grafana_password
EOF
    
    log "Arquivo de configuração criado: $env_file"
    info "Senha do banco de dados: $db_password"
    info "Senha do Grafana: $grafana_password"
    warn "IMPORTANTE: Guarde essas senhas em local seguro!"
}

# Verificar conectividade com Portainer
check_portainer() {
    local portainer_url="$1"
    local portainer_token="$2"
    
    if [[ -z "$portainer_url" || -z "$portainer_token" ]]; then
        warn "URL ou token do Portainer não fornecidos"
        return 1
    fi
    
    log "Verificando conectividade com Portainer..."
    
    local response=$(curl -s -w "%{http_code}" -H "Authorization: Bearer $portainer_token" \
        "$portainer_url/api/endpoints" -o /dev/null)
    
    if [[ "$response" == "200" ]]; then
        log "Conectividade com Portainer OK"
        return 0
    else
        error "Falha na conectividade com Portainer (HTTP $response)"
    fi
}

# Criar stack no Portainer via API
create_portainer_stack() {
    local portainer_url="$1"
    local portainer_token="$2"
    local endpoint_id="$3"
    
    if [[ -z "$portainer_url" || -z "$portainer_token" || -z "$endpoint_id" ]]; then
        error "Parâmetros obrigatórios não fornecidos para criação da stack"
    fi
    
    log "Criando stack StreamLeads no Portainer..."
    
    # Ler variáveis de ambiente
    local env_vars=""
    if [[ -f ".env.portainer" ]]; then
        while IFS='=' read -r key value; do
            # Ignorar comentários e linhas vazias
            [[ "$key" =~ ^#.*$ ]] && continue
            [[ -z "$key" ]] && continue
            
            env_vars="$env_vars,{\"name\":\"$key\",\"value\":\"$value\"}"
        done < .env.portainer
        
        # Remover vírgula inicial
        env_vars="[${env_vars:1}]"
    else
        env_vars="[]"
    fi
    
    # Payload para criação da stack
    local payload=$(cat << EOF
{
  "name": "streamleads",
  "repositoryURL": "https://github.com/brunopirz/streamleads",
  "repositoryReferenceName": "main",
  "composeFile": "docker-compose.portainer.yml",
  "env": $env_vars
}
EOF
)
    
    # Criar stack
    local response=$(curl -s -w "%{http_code}" \
        -H "Authorization: Bearer $portainer_token" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$portainer_url/api/stacks?type=2&method=repository&endpointId=$endpoint_id" \
        -o /tmp/portainer_response.json)
    
    if [[ "$response" == "200" ]]; then
        log "Stack StreamLeads criada com sucesso!"
        local stack_id=$(jq -r '.Id' /tmp/portainer_response.json 2>/dev/null || echo "unknown")
        info "ID da Stack: $stack_id"
    else
        error "Falha ao criar stack (HTTP $response)"
        if [[ -f "/tmp/portainer_response.json" ]]; then
            cat /tmp/portainer_response.json
        fi
    fi
    
    # Limpar arquivo temporário
    rm -f /tmp/portainer_response.json
}

# Exibir informações de acesso
show_access_info() {
    log "Configuração concluída!"
    echo
    info "Informações de Acesso:"
    echo "  📊 Dashboard: http://seu-servidor:8501"
    echo "  🔌 API: http://seu-servidor:8000"
    echo "  📚 Documentação API: http://seu-servidor:8000/docs"
    echo "  🌐 Nginx: http://seu-servidor (se configurado)"
    echo "  📈 Prometheus: http://seu-servidor:9090 (se habilitado)"
    echo "  📊 Grafana: http://seu-servidor:3000 (se habilitado)"
    echo
    info "Próximos passos:"
    echo "  1. Aguarde o download e inicialização dos containers"
    echo "  2. Verifique os logs no Portainer"
    echo "  3. Acesse o dashboard para configurar leads"
    echo "  4. Configure integrações (WhatsApp, Telegram, Email)"
    echo
    warn "Lembre-se de:"
    echo "  - Configurar SSL/HTTPS para produção"
    echo "  - Fazer backup regular dos dados"
    echo "  - Monitorar logs e métricas"
    echo "  - Atualizar senhas padrão"
}

# Menu interativo
interactive_setup() {
    echo
    info "=== StreamLeads - Configuração para Portainer ==="
    echo
    
    # Configurar ambiente
    setup_environment
    
    echo
    read -p "Deseja criar a stack automaticamente via API do Portainer? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo
        read -p "URL do Portainer (ex: https://portainer.exemplo.com): " portainer_url
        read -p "Token de acesso do Portainer: " portainer_token
        read -p "ID do endpoint (geralmente 1 para local): " endpoint_id
        
        if check_portainer "$portainer_url" "$portainer_token"; then
            create_portainer_stack "$portainer_url" "$portainer_token" "${endpoint_id:-1}"
        fi
    else
        info "Stack não criada automaticamente"
        echo "Para criar manualmente:"
        echo "1. Acesse seu Portainer"
        echo "2. Vá em Stacks > Add stack"
        echo "3. Use o repositório: https://github.com/brunopirz/streamleads"
        echo "4. Arquivo: docker-compose.portainer.yml"
        echo "5. Importe as variáveis do arquivo .env.portainer"
    fi
    
    show_access_info
}

# Função principal
main() {
    echo "🚀 StreamLeads - Setup para Portainer"
    echo "===================================="
    
    check_root
    check_dependencies
    
    # Verificar se estamos no diretório correto
    if [[ ! -f "docker-compose.portainer.yml" ]]; then
        error "Arquivo docker-compose.portainer.yml não encontrado. Execute este script no diretório raiz do projeto."
    fi
    
    case "${1:-interactive}" in
        "env")
            setup_environment
            ;;
        "check")
            check_portainer "$2" "$3"
            ;;
        "create")
            create_portainer_stack "$2" "$3" "$4"
            ;;
        "interactive")
            interactive_setup
            ;;
        "help")
            echo "Uso: $0 [comando] [argumentos]"
            echo
            echo "Comandos:"
            echo "  interactive    Configuração interativa (padrão)"
            echo "  env           Gerar apenas arquivo .env.portainer"
            echo "  check <url> <token>    Verificar conectividade com Portainer"
            echo "  create <url> <token> <endpoint_id>    Criar stack no Portainer"
            echo "  help          Exibir esta ajuda"
            ;;
        *)
            error "Comando inválido: $1. Use '$0 help' para ver os comandos disponíveis."
            ;;
    esac
}

# Executar função principal
main "$@"