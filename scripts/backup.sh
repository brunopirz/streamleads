#!/bin/bash

# =============================================================================
# SCRIPT DE BACKUP - STREAMLEADS
# =============================================================================
# Este script realiza backup completo do banco de dados PostgreSQL
# e pode ser executado manualmente ou via cron job

set -e  # Sair em caso de erro

# Configurações
BACKUP_DIR="/backups"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="streamleads_backup_${DATE}.sql"
COMPRESSED_FILE="streamleads_backup_${DATE}.sql.gz"
RETENTION_DAYS=${BACKUP_RETENTION_DAYS:-30}

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

# Verificar se o diretório de backup existe
if [ ! -d "$BACKUP_DIR" ]; then
    log "Criando diretório de backup: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
fi

# Verificar variáveis de ambiente
if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    log_error "Variáveis de ambiente do banco não configuradas!"
    log_error "Certifique-se que DB_NAME, DB_USER e DB_PASSWORD estão definidas."
    exit 1
fi

log "Iniciando backup do banco de dados StreamLeads..."
log "Banco: $DB_NAME"
log "Usuário: $DB_USER"
log "Arquivo: $BACKUP_FILE"

# Realizar backup
log "Executando pg_dump..."
if pg_dump -h db -U "$DB_USER" -d "$DB_NAME" > "$BACKUP_DIR/$BACKUP_FILE"; then
    log_success "Backup SQL criado com sucesso!"
else
    log_error "Falha ao criar backup SQL!"
    exit 1
fi

# Comprimir backup
log "Comprimindo backup..."
if gzip "$BACKUP_DIR/$BACKUP_FILE"; then
    log_success "Backup comprimido: $COMPRESSED_FILE"
else
    log_error "Falha ao comprimir backup!"
    exit 1
fi

# Verificar tamanho do arquivo
BACKUP_SIZE=$(du -h "$BACKUP_DIR/$COMPRESSED_FILE" | cut -f1)
log "Tamanho do backup: $BACKUP_SIZE"

# Upload para S3 (se configurado)
if [ "$BACKUP_S3_ENABLED" = "true" ] && [ -n "$BACKUP_S3_BUCKET" ]; then
    log "Enviando backup para S3..."
    
    if command -v aws >/dev/null 2>&1; then
        S3_KEY="backups/$(date +"%Y/%m/%d")/$COMPRESSED_FILE"
        
        if aws s3 cp "$BACKUP_DIR/$COMPRESSED_FILE" "s3://$BACKUP_S3_BUCKET/$S3_KEY"; then
            log_success "Backup enviado para S3: s3://$BACKUP_S3_BUCKET/$S3_KEY"
        else
            log_warning "Falha ao enviar backup para S3"
        fi
    else
        log_warning "AWS CLI não encontrado. Pulando upload para S3."
    fi
fi

# Limpeza de backups antigos
log "Limpando backups antigos (mais de $RETENTION_DAYS dias)..."
find "$BACKUP_DIR" -name "streamleads_backup_*.sql.gz" -type f -mtime +"$RETENTION_DAYS" -delete

REMAINING_BACKUPS=$(find "$BACKUP_DIR" -name "streamleads_backup_*.sql.gz" -type f | wc -l)
log "Backups restantes: $REMAINING_BACKUPS"

# Backup de arquivos de configuração
log "Fazendo backup de arquivos de configuração..."
CONFIG_BACKUP_DIR="$BACKUP_DIR/config_$DATE"
mkdir -p "$CONFIG_BACKUP_DIR"

# Copiar arquivos importantes (se existirem)
for file in docker-compose.prod.yml .env nginx.conf; do
    if [ -f "/app/$file" ]; then
        cp "/app/$file" "$CONFIG_BACKUP_DIR/"
        log "Backup de $file criado"
    fi
done

# Comprimir backup de configuração
if [ "$(ls -A $CONFIG_BACKUP_DIR)" ]; then
    tar -czf "$BACKUP_DIR/config_backup_$DATE.tar.gz" -C "$BACKUP_DIR" "config_$DATE"
    rm -rf "$CONFIG_BACKUP_DIR"
    log_success "Backup de configuração criado: config_backup_$DATE.tar.gz"
fi

# Backup de logs recentes (últimos 7 dias)
log "Fazendo backup de logs recentes..."
LOGS_BACKUP_DIR="$BACKUP_DIR/logs_$DATE"
mkdir -p "$LOGS_BACKUP_DIR"

if [ -d "/app/logs" ]; then
    find /app/logs -name "*.log" -mtime -7 -exec cp {} "$LOGS_BACKUP_DIR/" \;
    
    if [ "$(ls -A $LOGS_BACKUP_DIR)" ]; then
        tar -czf "$BACKUP_DIR/logs_backup_$DATE.tar.gz" -C "$BACKUP_DIR" "logs_$DATE"
        rm -rf "$LOGS_BACKUP_DIR"
        log_success "Backup de logs criado: logs_backup_$DATE.tar.gz"
    else
        rm -rf "$LOGS_BACKUP_DIR"
        log "Nenhum log recente encontrado"
    fi
fi

# Verificação de integridade do backup
log "Verificando integridade do backup..."
if gzip -t "$BACKUP_DIR/$COMPRESSED_FILE"; then
    log_success "Backup íntegro e válido!"
else
    log_error "Backup corrompido!"
    exit 1
fi

# Estatísticas finais
log "=== RESUMO DO BACKUP ==="
log "Data/Hora: $(date)"
log "Banco: $DB_NAME"
log "Arquivo: $COMPRESSED_FILE"
log "Tamanho: $BACKUP_SIZE"
log "Localização: $BACKUP_DIR"
log "Retenção: $RETENTION_DAYS dias"
log "Backups totais: $REMAINING_BACKUPS"

# Notificação (se configurado)
if [ "$SLACK_ENABLED" = "true" ] && [ -n "$SLACK_WEBHOOK_URL" ]; then
    SLACK_MESSAGE="✅ Backup do StreamLeads concluído com sucesso!\n📅 Data: $(date)\n💾 Arquivo: $COMPRESSED_FILE\n📏 Tamanho: $BACKUP_SIZE"
    
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"$SLACK_MESSAGE\"}" \
        "$SLACK_WEBHOOK_URL" >/dev/null 2>&1 || true
fi

log_success "Backup concluído com sucesso!"
exit 0