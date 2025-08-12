# 🎯 Sistema de Scoring e Automações StreamLeads

## Visão Geral

O sistema de scoring do StreamLeads é responsável por qualificar automaticamente os leads recebidos, atribuindo uma pontuação baseada em regras de negócio configuráveis e executando ações automáticas baseadas na classificação resultante.

## 🏆 Sistema de Scoring

### Metodologia

O scoring utiliza um sistema de pontuação acumulativa onde cada critério atendido adiciona pontos ao score total do lead. A classificação final é determinada por thresholds configuráveis.

### Regras de Pontuação

#### 1. Campos Obrigatórios (+10 pontos)
**Critério**: Todos os campos essenciais preenchidos

**Campos verificados**:
- ✅ Nome (não vazio)
- ✅ Email (formato válido)
- ✅ Telefone (formato brasileiro)
- ✅ Origem (valor válido)

**Implementação**:
```python
def _calculate_required_fields_score(self, lead: Lead) -> int:
    if all([
        lead.nome and lead.nome.strip(),
        lead.email and lead.email.strip(),
        lead.telefone and lead.telefone.strip(),
        lead.origem
    ]):
        return self.config.SCORE_CAMPOS_OBRIGATORIOS  # 10 pontos
    return 0
```

#### 2. Interesse em Alto Ticket (+15 pontos)
**Critério**: Interesse declarado em produtos/serviços de alto valor

**Palavras-chave detectadas**:
- 🏠 **Imóveis**: imóvel, apartamento, casa, cobertura, terreno
- 💰 **Investimentos**: investimento, aplicação, renda, patrimônio
- 🏢 **Comercial**: loja, escritório, galpão, comercial
- 🚗 **Veículos**: carro, veículo, automóvel (se aplicável)

**Implementação**:
```python
def _calculate_high_ticket_score(self, lead: Lead) -> int:
    if not lead.interesse:
        return 0
    
    interesse_lower = lead.interesse.lower()
    palavras_alto_ticket = [
        'imóvel', 'apartamento', 'casa', 'cobertura', 'terreno',
        'investimento', 'aplicação', 'renda', 'patrimônio',
        'loja', 'escritório', 'galpão', 'comercial'
    ]
    
    for palavra in palavras_alto_ticket:
        if palavra in interesse_lower:
            return self.config.SCORE_INTERESSE_ALTO_TICKET  # 15 pontos
    
    return 0
```

#### 3. Região Atendida (+5 pontos)
**Critério**: Lead localizado em região de atendimento da empresa

**Cidades atendidas** (configurável):
- São Paulo
- Rio de Janeiro
- Belo Horizonte
- Brasília
- Curitiba
- Porto Alegre

**Implementação**:
```python
def _calculate_region_score(self, lead: Lead) -> int:
    if not lead.cidade:
        return 0
    
    cidades_atendidas = [
        'são paulo', 'rio de janeiro', 'belo horizonte',
        'brasília', 'curitiba', 'porto alegre'
    ]
    
    cidade_lower = lead.cidade.lower().strip()
    if cidade_lower in cidades_atendidas:
        return self.config.SCORE_REGIAO_ATENDIDA  # 5 pontos
    
    return 0
```

#### 4. Bônus por Renda (0-10 pontos)
**Critério**: Renda aproximada informada (escala progressiva)

**Faixas de pontuação**:
- 💰 R$ 0 - R$ 3.000: 0 pontos
- 💰 R$ 3.001 - R$ 5.000: 2 pontos
- 💰 R$ 5.001 - R$ 8.000: 5 pontos
- 💰 R$ 8.001 - R$ 15.000: 8 pontos
- 💰 R$ 15.001+: 10 pontos

**Implementação**:
```python
def _calculate_income_bonus(self, lead: Lead) -> int:
    if not lead.renda_aproximada or lead.renda_aproximada <= 0:
        return 0
    
    renda = float(lead.renda_aproximada)
    
    if renda >= 15000:
        return 10
    elif renda >= 8000:
        return 8
    elif renda >= 5000:
        return 5
    elif renda >= 3000:
        return 2
    else:
        return 0
```

### Classificação dos Leads

#### 🔥 Lead Quente (≥ 25 pontos)
**Características**:
- Alta probabilidade de conversão
- Perfil ideal para o negócio
- Requer atenção imediata

**Exemplo de lead quente**:
```json
{
  "nome": "Carlos Silva",
  "email": "carlos@email.com",
  "telefone": "11999999999",
  "origem": "META_ADS",
  "interesse": "Apartamento para investimento",
  "renda_aproximada": 12000,
  "cidade": "São Paulo",
  "score": 33,
  "status": "QUENTE"
}
```
**Score detalhado**:
- Campos obrigatórios: +10
- Alto ticket (apartamento + investimento): +15
- Região atendida (São Paulo): +5
- Renda (R$ 12.000): +8
- **Total: 38 pontos**

#### 🟡 Lead Morno (15-24 pontos)
**Características**:
- Potencial moderado de conversão
- Necessita nutrição antes da abordagem
- Follow-up programado

**Exemplo de lead morno**:
```json
{
  "nome": "Ana Costa",
  "email": "ana@email.com",
  "telefone": "11888888888",
  "origem": "WEBSITE",
  "interesse": "Informações sobre imóveis",
  "renda_aproximada": 6000,
  "cidade": "Campinas",
  "score": 20,
  "status": "MORNO"
}
```
**Score detalhado**:
- Campos obrigatórios: +10
- Alto ticket (imóveis): +15
- Região não atendida: 0
- Renda (R$ 6.000): +5
- **Total: 30 pontos**

#### ❄️ Lead Frio (< 15 pontos)
**Características**:
- Baixa probabilidade de conversão imediata
- Perfil não ideal ou informações incompletas
- Inserido em campanhas de remarketing

**Exemplo de lead frio**:
```json
{
  "nome": "João Santos",
  "email": "joao@email.com",
  "telefone": "11777777777",
  "origem": "WHATSAPP",
  "interesse": "Dúvidas gerais",
  "renda_aproximada": null,
  "cidade": "Interior",
  "score": 10,
  "status": "FRIO"
}
```
**Score detalhado**:
- Campos obrigatórios: +10
- Alto ticket: 0
- Região não atendida: 0
- Renda não informada: 0
- **Total: 10 pontos**

---

## 🤖 Sistema de Automações

### Arquitetura

As automações são executadas em background tasks para não bloquear a API, utilizando o padrão Strategy para diferentes tipos de ações baseadas no status do lead.

### Automações por Status

#### 🔥 Lead Quente - Ação Imediata

**1. Notificação para Vendas**
```python
async def _notify_sales_team(self, lead: Lead):
    message = f"""
    🔥 LEAD QUENTE RECEBIDO!
    
    👤 Nome: {lead.nome}
    📧 Email: {lead.email}
    📱 Telefone: {lead.telefone}
    🎯 Interesse: {lead.interesse}
    💰 Renda: R$ {lead.renda_aproximada:,.2f}
    📍 Cidade: {lead.cidade}
    🏆 Score: {lead.score} pontos
    
    ⚡ AÇÃO REQUERIDA: Contato em até 1 hora!
    """
    
    # Slack
    await self._send_slack_notification(
        channel="#vendas-quentes",
        message=message,
        priority="high"
    )
    
    # WhatsApp (se configurado)
    await self._send_whatsapp_notification(
        phone=self.config.SALES_WHATSAPP,
        message=message
    )
```

**2. Envio para CRM via n8n**
```python
async def _send_to_n8n(self, lead: Lead, workflow_type: str):
    webhook_url = f"{self.config.N8N_WEBHOOK_URL}/{workflow_type}"
    
    payload = {
        "lead_id": lead.id,
        "nome": lead.nome,
        "email": lead.email,
        "telefone": lead.telefone,
        "origem": lead.origem,
        "interesse": lead.interesse,
        "renda_aproximada": lead.renda_aproximada,
        "cidade": lead.cidade,
        "score": lead.score,
        "status": lead.status,
        "priority": "high" if lead.status == "QUENTE" else "normal"
    }
    
    async with httpx.AsyncClient() as client:
        response = await client.post(webhook_url, json=payload)
        return response.status_code == 200
```

**3. Agendamento de Follow-up**
```python
async def _schedule_followup(self, lead: Lead, hours: int):
    followup_date = datetime.now() + timedelta(hours=hours)
    
    # Atualizar no banco
    lead.follow_up_date = followup_date
    
    # Agendar lembrete
    await self._schedule_reminder(
        lead_id=lead.id,
        reminder_date=followup_date,
        message=f"Follow-up agendado para {lead.nome}"
    )
```

#### 🟡 Lead Morno - Nutrição

**1. Email de Nutrição**
```python
async def _send_nurturing_email(self, lead: Lead):
    template = """
    Olá {nome},
    
    Obrigado pelo seu interesse em nossos serviços!
    
    Preparamos um material exclusivo sobre {interesse_area} 
    que pode ser muito útil para você.
    
    📎 Anexo: Guia Completo de Investimentos Imobiliários
    
    Em breve, nossa equipe entrará em contato para 
    esclarecer suas dúvidas e apresentar as melhores 
    oportunidades para seu perfil.
    
    Atenciosamente,
    Equipe StreamLeads
    """
    
    await self._send_email(
        to=lead.email,
        subject="Material Exclusivo - StreamLeads",
        body=template.format(
            nome=lead.nome,
            interesse_area=self._extract_interest_area(lead.interesse)
        ),
        attachments=["guia-investimentos.pdf"]
    )
```

**2. Sequência de Emails**
```python
async def _add_to_email_sequence(self, lead: Lead):
    sequence_data = {
        "email": lead.email,
        "nome": lead.nome,
        "interesse": lead.interesse,
        "sequence_type": "nurturing_morno",
        "start_date": datetime.now().isoformat()
    }
    
    await self._send_to_n8n(lead, "email-sequence")
```

#### ❄️ Lead Frio - Remarketing

**1. Inserção no CRM**
```python
async def _insert_into_crm(self, lead: Lead):
    crm_data = {
        "contact": {
            "name": lead.nome,
            "email": lead.email,
            "phone": lead.telefone,
            "source": lead.origem,
            "interest": lead.interesse,
            "city": lead.cidade,
            "score": lead.score,
            "status": "cold_lead",
            "tags": ["lead_frio", f"origem_{lead.origem.lower()}"]
        }
    }
    
    await self._send_to_n8n(lead, "crm-insert")
```

**2. Lista de Remarketing**
```python
async def _add_to_remarketing(self, lead: Lead):
    remarketing_data = {
        "email": lead.email,
        "nome": lead.nome,
        "interesse": lead.interesse,
        "origem": lead.origem,
        "list_type": "cold_leads_remarketing"
    }
    
    await self._send_to_n8n(lead, "remarketing-list")
```

### Configuração de Timings

```python
# Configurações de follow-up por status
FOLLOWUP_TIMINGS = {
    "QUENTE": 1,    # 1 hora
    "MORNO": 72,    # 3 dias
    "FRIO": 168     # 7 dias
}

# Configurações de retry para falhas
RETRY_CONFIG = {
    "max_attempts": 3,
    "backoff_factor": 2,
    "retry_delays": [1, 2, 4]  # minutos
}
```

---

## 🔧 Configuração e Personalização

### Variáveis de Ambiente

```bash
# Scoring
SCORE_CAMPOS_OBRIGATORIOS=10
SCORE_INTERESSE_ALTO_TICKET=15
SCORE_REGIAO_ATENDIDA=5

# Thresholds
SCORE_THRESHOLD_QUENTE=25
SCORE_THRESHOLD_MORNO=15

# Integrações
N8N_WEBHOOK_URL=https://n8n.empresa.com/webhook
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
WHATSAPP_API_URL=https://api.whatsapp.com/...

# Email
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=noreply@empresa.com
SMTP_PASSWORD=senha_app
```

### Personalização de Regras

#### Adicionando Nova Regra de Scoring

```python
class CustomLeadScoringService(LeadScoringService):
    def _calculate_custom_rule(self, lead: Lead) -> int:
        # Exemplo: Bônus para leads de final de semana
        if lead.created_at.weekday() >= 5:  # Sábado ou Domingo
            return 5
        return 0
    
    def calculate_score(self, lead: Lead) -> int:
        base_score = super().calculate_score(lead)
        custom_score = self._calculate_custom_rule(lead)
        return base_score + custom_score
```

#### Modificando Thresholds Dinamicamente

```python
class DynamicScoringService(LeadScoringService):
    def classify_lead(self, score: int, origem: str = None) -> LeadStatus:
        # Thresholds diferentes por origem
        if origem == "META_ADS":
            threshold_quente = 20  # Mais permissivo
            threshold_morno = 10
        else:
            threshold_quente = self.config.SCORE_THRESHOLD_QUENTE
            threshold_morno = self.config.SCORE_THRESHOLD_MORNO
        
        if score >= threshold_quente:
            return LeadStatus.QUENTE
        elif score >= threshold_morno:
            return LeadStatus.MORNO
        else:
            return LeadStatus.FRIO
```

---

## 📊 Métricas e Monitoramento

### KPIs de Scoring

1. **Taxa de Conversão por Status**
   - Leads Quentes → Vendas
   - Leads Mornos → Oportunidades
   - Leads Frios → Remarketing

2. **Distribuição de Scores**
   - Score médio por origem
   - Evolução temporal dos scores
   - Efetividade das regras

3. **Performance das Automações**
   - Taxa de sucesso de notificações
   - Tempo de resposta das integrações
   - Falhas e retries

### Logs de Auditoria

```python
# Exemplo de log estruturado
logger.info(
    "Lead scored",
    extra={
        "lead_id": lead.id,
        "score": score,
        "status": status,
        "rules_applied": {
            "required_fields": 10,
            "high_ticket": 15,
            "region": 5,
            "income_bonus": 8
        },
        "processing_time_ms": 150
    }
)
```

---

## 🧪 Testes e Validação

### Cenários de Teste

#### Teste de Scoring
```python
def test_lead_quente_scoring():
    lead = Lead(
        nome="Test User",
        email="test@email.com",
        telefone="11999999999",
        origem=LeadOrigin.META_ADS,
        interesse="Apartamento para investimento",
        renda_aproximada=15000,
        cidade="São Paulo"
    )
    
    service = LeadScoringService()
    score = service.calculate_score(lead)
    status = service.classify_lead(score)
    
    assert score >= 25
    assert status == LeadStatus.QUENTE
```

#### Teste de Automações
```python
@pytest.mark.asyncio
async def test_hot_lead_automation():
    lead = create_hot_lead()
    automation_service = AutomationService()
    
    result = await automation_service.process_lead(lead)
    
    assert result["slack_notified"] is True
    assert result["n8n_sent"] is True
    assert result["followup_scheduled"] is True
```

---

## 🚀 Próximos Passos

### Melhorias Planejadas

1. **Machine Learning**
   - Scoring baseado em histórico de conversões
   - Predição de probabilidade de fechamento
   - Otimização automática de thresholds

2. **Automações Avançadas**
   - Sequências de email personalizadas
   - Integração com calendário para agendamentos
   - Chatbot para qualificação inicial

3. **Analytics Avançados**
   - Dashboard de performance em tempo real
   - A/B testing de regras de scoring
   - Análise de cohort de leads

4. **Integrações Expandidas**
   - CRMs adicionais (Salesforce, Pipedrive)
   - Ferramentas de marketing (Mailchimp, RD Station)
   - Plataformas de comunicação (Teams, Discord)

---

**Documentação mantida por**: Equipe de Desenvolvimento StreamLeads  
**Última atualização**: Janeiro 2024  
**Versão**: 1.0.0