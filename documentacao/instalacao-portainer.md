# 📦 Instalação do StreamLeads no Portainer

Este guia detalha como instalar e configurar o StreamLeads no Portainer usando repositório Git.

## 📋 Pré-requisitos

- Portainer instalado e configurado
- Docker Swarm ou Docker Compose habilitado
- Acesso ao repositório GitHub do StreamLeads
- Conhecimento básico de Docker e Portainer

## 🚀 Instalação via Stack

### 1. Acessar o Portainer

1. Faça login no seu Portainer
2. Navegue até **Stacks** no menu lateral
3. Clique em **Add stack**

### 2. Configurar a Stack

#### Opção A: Via Repositório Git

1. **Nome da Stack**: `streamleads`
2. **Build method**: Selecione **Repository**
3. **Repository URL**: `https://github.com/brunopirz/streamleads.git`
4. **Repository reference**: `main` (ou `develop` para versão de desenvolvimento)
5. **Compose path**: `docker-compose.yml`

#### Opção B: Via Upload do docker-compose.yml

1. **Nome da Stack**: `streamleads`
2. **Build method**: Selecione **Upload**
3. Faça upload do arquivo `docker-compose.yml` do repositório

### 3. Configurar Variáveis de Ambiente

Na seção **Environment variables**, adicione as seguintes variáveis:

```env
# Configurações da Aplicação
APP_NAME=StreamLeads
APP_ENV=production
DEBUG=false
SECRET_KEY=sua_chave_secreta_super_segura_aqui

# Configurações do Banco de Dados
DATABASE_URL=postgresql://streamleads:senha_segura@db:5432/streamleads
POSTGRES_DB=streamleads
POSTGRES_USER=streamleads
POSTGRES_PASSWORD=senha_segura

# Configurações Redis
REDIS_URL=redis://redis:6379/0

# Configurações de Email (opcional)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=seu_email@gmail.com
SMTP_PASSWORD=sua_senha_app
SMTP_FROM=seu_email@gmail.com

# Configurações de Integração (opcional)
WHATSAPP_API_TOKEN=seu_token_whatsapp
TELEGRAM_BOT_TOKEN=seu_token_telegram

# Configurações de Monitoramento
SENTRY_DSN=sua_dsn_sentry
```

### 4. Configurações Avançadas (Opcional)

#### Recursos e Limites

Na seção **Advanced configuration**, você pode definir:

```yaml
services:
  app:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
          cpus: '0.25'
```

#### Redes Personalizadas

```yaml
networks:
  streamleads_network:
    driver: overlay
    attachable: true
```

### 5. Deploy da Stack

1. Revise todas as configurações
2. Clique em **Deploy the stack**
3. Aguarde o download das imagens e inicialização dos serviços

## 🔧 Configuração Pós-Instalação

### 1. Verificar Status dos Serviços

1. Acesse **Stacks** > **streamleads**
2. Verifique se todos os containers estão **running**
3. Monitore os logs em caso de problemas

### 2. Inicializar Banco de Dados

Execute o comando de inicialização do banco:

```bash
# Via Portainer Console
docker exec -it streamleads_app_1 python scripts/init_db.py
```

Ou use o console do Portainer:
1. Acesse **Containers**
2. Clique no container `streamleads_app`
3. Vá em **Console**
4. Execute: `python scripts/init_db.py`

### 3. Acessar a Aplicação

- **API**: `http://seu-servidor:8000`
- **Dashboard**: `http://seu-servidor:8501`
- **Documentação API**: `http://seu-servidor:8000/docs`

## 🔄 Atualizações

### Atualização Automática via Webhook (Recomendado)

1. Configure um webhook no GitHub:
   - URL: `http://seu-portainer:9000/api/stacks/webhooks/sua-webhook-id`
   - Eventos: `push` na branch `main`

2. No Portainer:
   - Acesse **Stacks** > **streamleads**
   - Vá em **Webhooks**
   - Clique em **Create webhook**
   - Copie a URL gerada

### Atualização Manual

1. Acesse **Stacks** > **streamleads**
2. Clique em **Editor**
3. Clique em **Pull and redeploy**
4. Confirme a operação

## 📊 Monitoramento

### Logs

1. **Via Portainer**:
   - Acesse **Containers**
   - Clique no container desejado
   - Vá em **Logs**

2. **Via Stack**:
   - Acesse **Stacks** > **streamleads**
   - Clique em **Logs**

### Métricas

- **CPU/Memória**: Disponível na aba **Stats** de cada container
- **Rede**: Monitoramento de tráfego de rede
- **Volumes**: Uso de espaço em disco

## 🛠️ Troubleshooting

### Problemas Comuns

#### Container não inicia

1. Verifique os logs do container
2. Confirme se todas as variáveis de ambiente estão configuradas
3. Verifique se as portas não estão em conflito

#### Erro de conexão com banco

1. Verifique se o container `db` está rodando
2. Confirme as credenciais do banco
3. Teste a conectividade entre containers

#### Aplicação não responde

1. Verifique se o container `app` está healthy
2. Confirme se as portas estão mapeadas corretamente
3. Verifique os logs da aplicação

### Comandos Úteis

```bash
# Verificar status dos containers
docker ps

# Ver logs de um container específico
docker logs streamleads_app_1

# Acessar shell do container
docker exec -it streamleads_app_1 bash

# Reiniciar um serviço específico
docker restart streamleads_app_1
```

## 🔒 Segurança

### Recomendações

1. **Senhas Fortes**: Use senhas complexas para banco de dados
2. **HTTPS**: Configure SSL/TLS para produção
3. **Firewall**: Restrinja acesso às portas necessárias
4. **Backup**: Configure backup automático dos dados
5. **Atualizações**: Mantenha as imagens sempre atualizadas

### Configuração de Secrets

Para ambientes de produção, use Docker Secrets:

```yaml
secrets:
  db_password:
    external: true
  secret_key:
    external: true

services:
  app:
    secrets:
      - db_password
      - secret_key
```

## 📚 Recursos Adicionais

- [Documentação do Portainer](https://docs.portainer.io/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Repositório do StreamLeads](https://github.com/brunopirz/streamleads)
- [Documentação da API](http://seu-servidor:8000/docs)

## 🆘 Suporte

Em caso de problemas:

1. Consulte os logs detalhados
2. Verifique a documentação técnica
3. Abra uma issue no repositório GitHub
4. Entre em contato com a equipe de suporte

---

**Nota**: Esta documentação assume uma instalação padrão do Portainer. Ajuste as configurações conforme seu ambiente específico.