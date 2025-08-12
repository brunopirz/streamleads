#!/bin/bash

# =============================================================================
# SCRIPT DE DEPLOY - STREAMLEADS
# =============================================================================
# Este script automatiza o processo de deploy em produção
# Inclui backup, atualização, migrações e verificações de saúde

set -e  # Sair em caso de erro

# Configurações
PROJECT_DIR="/opt/streamleads"
BACKUP_DIR="$PROJECT_DIR/backups"
LOG_FILE="$PROJECT_DIR/logs/deploy.log"
COMPOSE_FILE="docker-compose.prod.yml"
MAX_WAIT_TIME=300  # 5 minutos
HEALTH_CHECK_RETRIES=10

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
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${BLUE}$message${NC}"
    echo "$message" >> "$LOG_FILE"
}

log_success() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1"
    echo -e "${GREEN}$message${NC}"
    echo "$message" >> "$LOG_FILE"
}

log_warning() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1"
    echo -e "${YELLOW}$message${NC}"
    echo "$message" >> "$LOG_FILE"
}

log_error() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1"
    echo -e "${RED}$message${NC}"
    echo "$message" >> "$LOG_FILE"
}

log_info() {
    local message="[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️  $1"
    echo -e "${CYAN}$message${NC}"
    echo "$message" >> "$LOG_FILE"
}

# Função para mostrar banner
show_banner() {
    echo -e "${PURPLE}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "                    🚀 STREAMLEADS DEPLOY                     "
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${NC}"
}

# Função para verificar pré-requisitos
check_prerequisites() {
    log "Verificando pré-requisitos..."
    
    # Verificar se está no diretório correto
    if [ ! -f "$COMPOSE_FILE" ]; then
        log_error "Arquivo $COMPOSE_FILE não encontrado!"
        log_error "Certifique-se de estar no diretório correto: $PROJECT_DIR"
        exit 1
    fi
    
    # Verificar Docker
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker não encontrado!"
        exit 1
    fi
    
    # Verificar Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "Docker Compose não encontrado!"
        exit 1
    fi
    
    # Verificar arquivo .env
    if [ ! -f ".env" ]; then
        log_error "Arquivo .env não encontrado!"
        log_error "Copie .env.prod.example para .env e configure as variáveis."
        exit 1
    fi
    
    # Verificar espaço em disco
    AVAILABLE_SPACE=$(df . | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_SPACE" -lt 1048576 ]; then  # 1GB em KB
        log_warning "Pouco espaço em disco disponível: $(df -h . | awk 'NR==2 {print $4}')"
    fi
    
    log_success "Pré-requisitos verificados!"
}

# Função para fazer backup antes do deploy
backup_before_deploy() {
    log "Criando backup antes do deploy..."
    
    # Criar diretório de backup se não existir
    mkdir -p "$BACKUP_DIR"
    
    # Executar script de backup
    if [ -f "scripts/backup.sh" ]; then
        chmod +x scripts/backup.sh
        if docker-compose -f "$COMPOSE_FILE" run --rm backup /backup.sh; then
            log_success "Backup criado com sucesso!"
        else
            log_error "Falha ao criar backup!"
            read -p "Continuar mesmo assim? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        log_warning "Script de backup não encontrado. Pulando backup automático."
    fi
}

# Função para atualizar código
update_code() {
    log "Atualizando código do repositório..."
    
    # Verificar se é um repositório Git
    if [ -d ".git" ]; then
        # Salvar mudanças locais (se houver)
        if ! git diff --quiet; then
            log_warning "Mudanças locais detectadas. Salvando..."
            git stash push -m "Deploy stash $(date)"
        fi
        
        # Atualizar código
        git fetch origin
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        log "Branch atual: $CURRENT_BRANCH"
        
        if git pull origin "$CURRENT_BRANCH"; then
            log_success "Código atualizado com sucesso!"
        else
            log_error "Falha ao atualizar código!"
            exit 1
        fi
        
        # Mostrar últimos commits
        log "Últimos commits:"
        git log --oneline -5
    else
        log_warning "Não é um repositório Git. Pulando atualização de código."
    fi
}

# Função para construir imagens
build_images() {
    log "Construindo imagens Docker..."
    
    if docker-compose -f "$COMPOSE_FILE" build --no-cache; then
        log_success "Imagens construídas com sucesso!"
    else
        log_error "Falha ao construir imagens!"
        exit 1
    fi
}

# Função para parar serviços
stop_services() {
    log "Parando serviços..."
    
    if docker-compose -f "$COMPOSE_FILE" down; then
        log_success "Serviços parados com sucesso!"
    else
        log_warning "Alguns serviços podem não ter parado corretamente."
    fi
}

# Função para executar migrações
run_migrations() {
    log "Executando migrações do banco de dados..."
    
    # Iniciar apenas o banco para migrações
    docker-compose -f "$COMPOSE_FILE" up -d db redis
    
    # Aguardar banco ficar pronto
    log "Aguardando banco de dados..."
    sleep 10
    
    # Executar migrações
    if docker-compose -f "$COMPOSE_FILE" run --rm api alembic upgrade head; then
        log_success "Migrações executadas com sucesso!"
    else
        log_error "Falha ao executar migrações!"
        exit 1
    fi
}

# Função para iniciar serviços
start_services() {
    log "Iniciando serviços..."
    
    if docker-compose -f "$COMPOSE_FILE" up -d; then
        log_success "Serviços iniciados!"
    else
        log_error "Falha ao iniciar serviços!"
        exit 1
    fi
}

# Função para verificar saúde dos serviços
check_health() {
    log "Verificando saúde dos serviços..."
    
    local retries=0
    local max_retries=$HEALTH_CHECK_RETRIES
    
    while [ $retries -lt $max_retries ]; do
        log "Tentativa $((retries + 1))/$max_retries..."
        
        # Verificar API
        if curl -f -s "http://localhost:8000/health" >/dev/null; then
            log_success "API está saudável!"
            
            # Verificar Dashboard
            if curl -f -s "http://localhost:8501/_stcore/health" >/dev/null; then
                log_success "Dashboard está saudável!"
                return 0
            else
                log_warning "Dashboard não está respondendo..."
            fi
        else
            log_warning "API não está respondendo..."
        fi
        
        retries=$((retries + 1))
        if [ $retries -lt $max_retries ]; then
            sleep 10
        fi
    done
    
    log_error "Serviços não estão saudáveis após $max_retries tentativas!"
    return 1
}

# Função para mostrar status dos serviços
show_status() {
    log "Status dos serviços:"
    docker-compose -f "$COMPOSE_FILE" ps
    
    log "\nLogs recentes da API:"
    docker-compose -f "$COMPOSE_FILE" logs --tail=10 api
    
    log "\nUso de recursos:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
}

# Função para limpeza
cleanup() {
    log "Executando limpeza..."
    
    # Remover imagens não utilizadas
    docker image prune -f
    
    # Remover volumes órfãos
    docker volume prune -f
    
    # Remover redes não utilizadas
    docker network prune -f
    
    log_success "Limpeza concluída!"
}

# Função para rollback
rollback() {
    log_error "Iniciando rollback..."
    
    # Parar serviços atuais
    docker-compose -f "$COMPOSE_FILE" down
    
    # Voltar para commit anterior
    if [ -d ".git" ]; then
        git reset --hard HEAD~1
        log "Código revertido para commit anterior"
    fi
    
    # Restaurar backup mais recente
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/streamleads_backup_*.sql.gz 2>/dev/null | head -1)
    if [ -n "$LATEST_BACKUP" ]; then
        log "Restaurando backup: $LATEST_BACKUP"
        # Aqui você implementaria a restauração do backup
        # gunzip -c "$LATEST_BACKUP" | docker-compose -f "$COMPOSE_FILE" exec -T db psql -U postgres -d streamleads
    fi
    
    # Reiniciar serviços
    docker-compose -f "$COMPOSE_FILE" up -d
    
    log_warning "Rollback concluído. Verifique os serviços."
}

# Função para enviar notificações
send_notifications() {
    local status=$1
    local message=$2
    
    # Slack
    if [ "$SLACK_ENABLED" = "true" ] && [ -n "$SLACK_WEBHOOK_URL" ]; then
        local emoji="✅"
        if [ "$status" = "error" ]; then
            emoji="❌"
        elif [ "$status" = "warning" ]; then
            emoji="⚠️"
        fi
        
        local slack_message="$emoji StreamLeads Deploy\n📅 $(date)\n📝 $message\n🖥️ Servidor: $(hostname)"
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$slack_message\"}" \
            "$SLACK_WEBHOOK_URL" >/dev/null 2>&1 || true
    fi
    
    # Discord
    if [ "$DISCORD_ENABLED" = "true" ] && [ -n "$DISCORD_WEBHOOK_URL" ]; then
        local discord_message="**StreamLeads Deploy**\n📅 $(date)\n📝 $message\n🖥️ Servidor: $(hostname)"
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"content\":\"$discord_message\"}" \
            "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1 || true
    fi
}

# Função principal
main() {
    # Criar diretório de logs se não existir
    mkdir -p "$(dirname "$LOG_FILE")"
    
    show_banner
    
    log "Iniciando deploy do StreamLeads..."
    log "Diretório: $(pwd)"
    log "Usuário: $(whoami)"
    log "Data/Hora: $(date)"
    
    # Verificar se deve fazer rollback
    if [ "$1" = "rollback" ]; then
        rollback
        exit 0
    fi
    
    # Trap para capturar erros e fazer rollback se necessário
    trap 'log_error "Deploy falhou! Execute: $0 rollback"; send_notifications "error" "Deploy falhou!"; exit 1' ERR
    
    # Executar etapas do deploy
    check_prerequisites
    backup_before_deploy
    update_code
    build_images
    stop_services
    run_migrations
    start_services
    
    # Aguardar serviços ficarem prontos
    log "Aguardando serviços ficarem prontos..."
    sleep 30
    
    # Verificar saúde
    if check_health; then
        log_success "Deploy concluído com sucesso!"
        show_status
        cleanup
        send_notifications "success" "Deploy concluído com sucesso!"
    else
        log_error "Deploy falhou na verificação de saúde!"
        send_notifications "error" "Deploy falhou na verificação de saúde!"
        exit 1
    fi
    
    log "\n🎉 Deploy finalizado! Acesse:"
    log "   📊 Dashboard: https://dashboard.${DOMAIN:-localhost}"
    log "   🔧 API: https://api.${DOMAIN:-localhost}"
    log "   📚 Docs: https://api.${DOMAIN:-localhost}/docs"
    log "   🌸 Flower: https://flower.${DOMAIN:-localhost}"
    log "   📈 Grafana: https://grafana.${DOMAIN:-localhost}"
}

# Verificar argumentos
case "$1" in
    "rollback")
        rollback
        ;;
    "status")
        show_status
        ;;
    "health")
        check_health
        ;;
    "")
        main
        ;;
    *)
        echo "Uso: $0 [rollback|status|health]"
        echo "  rollback - Reverte para versão anterior"
        echo "  status   - Mostra status dos serviços"
        echo "  health   - Verifica saúde dos serviços"
        exit 1
        ;;
esac