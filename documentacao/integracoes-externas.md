# 🔗 Integrações Externas - StreamLeads

## Visão Geral

O StreamLeads foi projetado para integrar-se facilmente com diversos sistemas externos, permitindo automação completa do fluxo de leads. Este documento detalha todas as integrações disponíveis e como configurá-las.

## 🎯 n8n - Orquestração de Automações

### Visão Geral

O n8n é o coração das automações do StreamLeads, permitindo criar fluxos complexos sem código.

### Configuração

**Variáveis de ambiente**:
```env
N8N_WEBHOOK_URL=https://n8n.empresa.com/webhook/streamleads
N8N_API_KEY=your_n8n_api_key
N8N_WORKFLOW_ID_HOT=workflow_123
N8N_WORKFLOW_ID_WARM=workflow_456
N8N_WORKFLOW_ID_COLD=workflow_789
```

### Workflows Recomendados

#### 1. Lead Quente - Vendas Imediatas

**Trigger**: Webhook do StreamLeads
**Fluxo**:
1. Receber dados do lead
2. Validar informações
3. Enviar para CRM (HubSpot/Pipedrive)
4. Notificar vendedor via WhatsApp
5. Agendar follow-up em 2 horas
6. Criar tarefa no Asana/Trello

**Exemplo de payload**:
```json
{
  "lead_id": 123,
  "nome": "Carlos Silva",
  "email": "carlos@email.com",
  "telefone": "11999999999",
  "score": 35,
  "status": "QUENTE",
  "interesse": "Apartamento para investimento",
  "renda_aproximada": 15000,
  "cidade": "São Paulo",
  "origem": "META_ADS",
  "created_at": "2024-01-15T10:30:00Z"
}
```

#### 2. Lead Morno - Nutrição

**Trigger**: Webhook do StreamLeads
**Fluxo**:
1. Receber dados do lead
2. Adicionar ao CRM com tag "Nutrição"
3. Enviar email de boas-vindas
4. Adicionar à sequência de emails (7 dias)
5. Agendar follow-up em 3 dias
6. Adicionar ao remarketing do Facebook

#### 3. Lead Frio - CRM e Remarketing

**Trigger**: Webhook do StreamLeads
**Fluxo**:
1. Receber dados do lead
2. Adicionar ao CRM com tag "Frio"
3. Adicionar à lista de remarketing
4. Agendar follow-up em 7 dias
5. Enviar para automação de nutrição longa

### Configuração no n8n

**1. Webhook Node**:
```json
{
  "httpMethod": "POST",
  "path": "streamleads",
  "responseMode": "responseNode",
  "options": {}
}
```

**2. Function Node - Processar Lead**:
```javascript
// Processar dados do lead
const lead = items[0].json;

// Determinar ações baseadas no status
let actions = [];

switch(lead.status) {
  case 'QUENTE':
    actions = ['crm', 'whatsapp', 'vendas', 'followup_2h'];
    break;
  case 'MORNO':
    actions = ['crm', 'email_welcome', 'sequence', 'followup_3d'];
    break;
  case 'FRIO':
    actions = ['crm', 'remarketing', 'followup_7d'];
    break;
}

return {
  json: {
    ...lead,
    actions: actions,
    processed_at: new Date().toISOString()
  }
};
```

**3. HTTP Request Node - CRM**:
```json
{
  "method": "POST",
  "url": "https://api.hubspot.com/crm/v3/objects/contacts",
  "headers": {
    "Authorization": "Bearer {{$env.HUBSPOT_API_KEY}}",
    "Content-Type": "application/json"
  },
  "body": {
    "properties": {
      "email": "={{$json.email}}",
      "firstname": "={{$json.nome.split(' ')[0]}}",
      "lastname": "={{$json.nome.split(' ').slice(1).join(' ')}}",
      "phone": "={{$json.telefone}}",
      "lead_source": "={{$json.origem}}",
      "lead_score": "={{$json.score}}",
      "lead_status": "={{$json.status}}"
    }
  }
}
```

## 📱 WhatsApp Business API

### Configuração

**Variáveis de ambiente**:
```env
WHATSAPP_API_URL=https://graph.facebook.com/v18.0
WHATSAPP_ACCESS_TOKEN=your_whatsapp_token
WHATSAPP_PHONE_NUMBER_ID=123456789
WHATSAPP_VERIFY_TOKEN=your_verify_token
```

### Templates de Mensagem

#### 1. Notificação de Lead Quente

**Nome**: `lead_quente_vendas`
**Categoria**: `UTILITY`
**Idioma**: `pt_BR`

**Conteúdo**:
```
🔥 *LEAD QUENTE RECEBIDO*

👤 *Nome:* {{1}}
📧 *Email:* {{2}}
📱 *Telefone:* {{3}}
🎯 *Interesse:* {{4}}
💰 *Renda:* R$ {{5}}
📍 *Cidade:* {{6}}
⭐ *Score:* {{7}}/40

🚀 *Ação necessária:* Contato imediato!
```

#### 2. Follow-up Automático

**Nome**: `followup_lead`
**Categoria**: `MARKETING`
**Idioma**: `pt_BR`

**Conteúdo**:
```
Olá {{1}}! 👋

Obrigado pelo seu interesse em nossos imóveis.

Gostaria de agendar uma conversa para entender melhor suas necessidades?

Estou disponível hoje das 9h às 18h.

Aguardo seu retorno! 😊
```

### Implementação

**Serviço WhatsApp**:
```python
import httpx
from typing import Dict, Any
from app.config import settings

class WhatsAppService:
    def __init__(self):
        self.api_url = settings.WHATSAPP_API_URL
        self.access_token = settings.WHATSAPP_ACCESS_TOKEN
        self.phone_number_id = settings.WHATSAPP_PHONE_NUMBER_ID
    
    async def send_template_message(
        self, 
        to: str, 
        template_name: str, 
        parameters: list
    ) -> Dict[str, Any]:
        """Enviar mensagem usando template."""
        url = f"{self.api_url}/{self.phone_number_id}/messages"
        
        payload = {
            "messaging_product": "whatsapp",
            "to": to,
            "type": "template",
            "template": {
                "name": template_name,
                "language": {"code": "pt_BR"},
                "components": [
                    {
                        "type": "body",
                        "parameters": [
                            {"type": "text", "text": param}
                            for param in parameters
                        ]
                    }
                ]
            }
        }
        
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json"
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(url, json=payload, headers=headers)
            return response.json()
    
    async def notify_hot_lead(self, lead: Dict[str, Any], vendedor_phone: str):
        """Notificar vendedor sobre lead quente."""
        parameters = [
            lead["nome"],
            lead["email"],
            lead["telefone"],
            lead["interesse"],
            str(lead["renda_aproximada"]),
            lead["cidade"],
            str(lead["score"])
        ]
        
        return await self.send_template_message(
            to=vendedor_phone,
            template_name="lead_quente_vendas",
            parameters=parameters
        )
```

## 💬 Slack - Notificações da Equipe

### Configuração

**Variáveis de ambiente**:
```env
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX
SLACK_CHANNEL_VENDAS=#vendas
SLACK_CHANNEL_MARKETING=#marketing
```

### Implementação

**Serviço Slack**:
```python
import httpx
from typing import Dict, Any
from app.config import settings

class SlackService:
    def __init__(self):
        self.webhook_url = settings.SLACK_WEBHOOK_URL
    
    async def send_notification(
        self, 
        channel: str, 
        message: str, 
        attachments: list = None
    ) -> Dict[str, Any]:
        """Enviar notificação para Slack."""
        payload = {
            "channel": channel,
            "text": message,
            "username": "StreamLeads Bot",
            "icon_emoji": ":rocket:"
        }
        
        if attachments:
            payload["attachments"] = attachments
        
        async with httpx.AsyncClient() as client:
            response = await client.post(self.webhook_url, json=payload)
            return response.json()
    
    async def notify_hot_lead(self, lead: Dict[str, Any]):
        """Notificar sobre lead quente."""
        attachment = {
            "color": "#ff6b6b",
            "title": "🔥 Lead Quente Recebido!",
            "fields": [
                {"title": "Nome", "value": lead["nome"], "short": True},
                {"title": "Email", "value": lead["email"], "short": True},
                {"title": "Telefone", "value": lead["telefone"], "short": True},
                {"title": "Score", "value": f"{lead['score']}/40", "short": True},
                {"title": "Interesse", "value": lead["interesse"], "short": False},
                {"title": "Origem", "value": lead["origem"], "short": True},
                {"title": "Cidade", "value": lead["cidade"], "short": True}
            ],
            "footer": "StreamLeads",
            "ts": int(lead["created_at"].timestamp())
        }
        
        return await self.send_notification(
            channel=settings.SLACK_CHANNEL_VENDAS,
            message="Novo lead quente necessita atenção imediata!",
            attachments=[attachment]
        )
```

## 📧 Email Marketing

### Configuração SMTP

**Variáveis de ambiente**:
```env
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=noreply@empresa.com
SMTP_PASSWORD=app_password
SMTP_USE_TLS=true
```

### Templates de Email

#### 1. Email de Boas-vindas

**Assunto**: `Bem-vindo! Vamos encontrar seu imóvel ideal 🏠`

**HTML**:
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Bem-vindo ao StreamLeads</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #007bff; color: white; padding: 20px; text-align: center; }
        .content { padding: 20px; background: #f9f9f9; }
        .button { display: inline-block; padding: 12px 24px; background: #28a745; color: white; text-decoration: none; border-radius: 5px; }
        .footer { text-align: center; padding: 20px; font-size: 12px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏠 Bem-vindo!</h1>
        </div>
        <div class="content">
            <h2>Olá, {{nome}}!</h2>
            <p>Obrigado por demonstrar interesse em nossos imóveis. Estamos aqui para ajudá-lo a encontrar a propriedade perfeita!</p>
            
            <h3>📋 Suas informações:</h3>
            <ul>
                <li><strong>Interesse:</strong> {{interesse}}</li>
                <li><strong>Cidade:</strong> {{cidade}}</li>
                <li><strong>Origem:</strong> {{origem}}</li>
            </ul>
            
            <p>Nossa equipe analisará seu perfil e entrará em contato em breve com opções personalizadas.</p>
            
            <div style="text-align: center; margin: 30px 0;">
                <a href="https://empresa.com/agendar" class="button">Agendar Conversa</a>
            </div>
            
            <p>Enquanto isso, que tal conhecer alguns de nossos imóveis em destaque?</p>
        </div>
        <div class="footer">
            <p>© 2024 Empresa Imobiliária. Todos os direitos reservados.</p>
            <p>Se não deseja mais receber emails, <a href="{{unsubscribe_link}}">clique aqui</a>.</p>
        </div>
    </div>
</body>
</html>
```

#### 2. Email de Nutrição

**Assunto**: `5 dicas para escolher o imóvel ideal 💡`

### Implementação

**Serviço de Email**:
```python
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
from typing import Dict, Any, Optional
from jinja2 import Template
from app.config import settings

class EmailService:
    def __init__(self):
        self.smtp_server = settings.SMTP_SERVER
        self.smtp_port = settings.SMTP_PORT
        self.username = settings.SMTP_USERNAME
        self.password = settings.SMTP_PASSWORD
        self.use_tls = settings.SMTP_USE_TLS
    
    def _get_smtp_connection(self):
        """Criar conexão SMTP."""
        server = smtplib.SMTP(self.smtp_server, self.smtp_port)
        if self.use_tls:
            server.starttls()
        server.login(self.username, self.password)
        return server
    
    async def send_email(
        self,
        to_email: str,
        subject: str,
        html_content: str,
        text_content: Optional[str] = None,
        attachments: Optional[list] = None
    ) -> bool:
        """Enviar email."""
        try:
            msg = MIMEMultipart('alternative')
            msg['From'] = self.username
            msg['To'] = to_email
            msg['Subject'] = subject
            
            # Adicionar conteúdo texto
            if text_content:
                text_part = MIMEText(text_content, 'plain', 'utf-8')
                msg.attach(text_part)
            
            # Adicionar conteúdo HTML
            html_part = MIMEText(html_content, 'html', 'utf-8')
            msg.attach(html_part)
            
            # Adicionar anexos
            if attachments:
                for attachment in attachments:
                    with open(attachment['path'], 'rb') as f:
                        part = MIMEBase('application', 'octet-stream')
                        part.set_payload(f.read())
                        encoders.encode_base64(part)
                        part.add_header(
                            'Content-Disposition',
                            f'attachment; filename= {attachment["name"]}'
                        )
                        msg.attach(part)
            
            # Enviar email
            with self._get_smtp_connection() as server:
                server.send_message(msg)
            
            return True
        except Exception as e:
            print(f"Erro ao enviar email: {e}")
            return False
    
    async def send_welcome_email(self, lead: Dict[str, Any]) -> bool:
        """Enviar email de boas-vindas."""
        template = Template(WELCOME_EMAIL_TEMPLATE)
        
        html_content = template.render(
            nome=lead['nome'],
            interesse=lead['interesse'],
            cidade=lead['cidade'],
            origem=lead['origem'],
            unsubscribe_link=f"https://empresa.com/unsubscribe?email={lead['email']}"
        )
        
        return await self.send_email(
            to_email=lead['email'],
            subject="Bem-vindo! Vamos encontrar seu imóvel ideal 🏠",
            html_content=html_content
        )
```

## 🏢 CRM - HubSpot

### Configuração

**Variáveis de ambiente**:
```env
HUBSPOT_API_KEY=your_hubspot_api_key
HUBSPOT_PORTAL_ID=12345678
```

### Implementação

**Serviço HubSpot**:
```python
import httpx
from typing import Dict, Any, Optional
from app.config import settings

class HubSpotService:
    def __init__(self):
        self.api_key = settings.HUBSPOT_API_KEY
        self.base_url = "https://api.hubapi.com"
    
    async def create_contact(self, lead: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Criar contato no HubSpot."""
        url = f"{self.base_url}/crm/v3/objects/contacts"
        
        # Mapear dados do lead para HubSpot
        properties = {
            "email": lead["email"],
            "firstname": lead["nome"].split()[0],
            "lastname": " ".join(lead["nome"].split()[1:]) if len(lead["nome"].split()) > 1 else "",
            "phone": lead["telefone"],
            "city": lead["cidade"],
            "lead_source": lead["origem"],
            "lead_score": str(lead["score"]),
            "lead_status": lead["status"],
            "lead_interest": lead["interesse"],
            "annual_revenue": str(lead.get("renda_aproximada", 0) * 12) if lead.get("renda_aproximada") else None
        }
        
        # Remover valores None
        properties = {k: v for k, v in properties.items() if v is not None}
        
        payload = {"properties": properties}
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(url, json=payload, headers=headers)
                
                if response.status_code == 201:
                    return response.json()
                elif response.status_code == 409:
                    # Contato já existe, tentar atualizar
                    return await self.update_contact_by_email(lead["email"], properties)
                else:
                    print(f"Erro ao criar contato: {response.status_code} - {response.text}")
                    return None
        except Exception as e:
            print(f"Erro na requisição HubSpot: {e}")
            return None
    
    async def update_contact_by_email(self, email: str, properties: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Atualizar contato existente por email."""
        url = f"{self.base_url}/crm/v3/objects/contacts/{email}"
        
        payload = {"properties": properties}
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.patch(url, json=payload, headers=headers)
                
                if response.status_code == 200:
                    return response.json()
                else:
                    print(f"Erro ao atualizar contato: {response.status_code} - {response.text}")
                    return None
        except Exception as e:
            print(f"Erro na atualização HubSpot: {e}")
            return None
    
    async def create_deal(self, contact_id: str, lead: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Criar negócio no HubSpot."""
        url = f"{self.base_url}/crm/v3/objects/deals"
        
        # Determinar valor estimado baseado no interesse
        deal_value = self._estimate_deal_value(lead["interesse"], lead.get("renda_aproximada"))
        
        properties = {
            "dealname": f"Lead {lead['nome']} - {lead['interesse']}",
            "amount": str(deal_value),
            "dealstage": self._get_deal_stage(lead["status"]),
            "pipeline": "default",
            "lead_source": lead["origem"],
            "description": f"Lead Score: {lead['score']} | Interesse: {lead['interesse']}"
        }
        
        payload = {
            "properties": properties,
            "associations": [
                {
                    "to": {"id": contact_id},
                    "types": [{"associationCategory": "HUBSPOT_DEFINED", "associationTypeId": 3}]
                }
            ]
        }
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(url, json=payload, headers=headers)
                
                if response.status_code == 201:
                    return response.json()
                else:
                    print(f"Erro ao criar deal: {response.status_code} - {response.text}")
                    return None
        except Exception as e:
            print(f"Erro na criação de deal: {e}")
            return None
    
    def _estimate_deal_value(self, interesse: str, renda: Optional[float]) -> int:
        """Estimar valor do negócio baseado no interesse e renda."""
        base_values = {
            "apartamento": 300000,
            "casa": 500000,
            "investimento": 400000,
            "comercial": 800000
        }
        
        # Buscar palavra-chave no interesse
        interesse_lower = interesse.lower()
        value = 250000  # Valor padrão
        
        for keyword, base_value in base_values.items():
            if keyword in interesse_lower:
                value = base_value
                break
        
        # Ajustar baseado na renda
        if renda:
            if renda >= 15000:
                value = int(value * 1.5)
            elif renda >= 10000:
                value = int(value * 1.2)
            elif renda <= 3000:
                value = int(value * 0.7)
        
        return value
    
    def _get_deal_stage(self, lead_status: str) -> str:
        """Mapear status do lead para estágio do deal."""
        mapping = {
            "QUENTE": "appointmentscheduled",
            "MORNO": "qualifiedtobuy",
            "FRIO": "presentationscheduled"
        }
        return mapping.get(lead_status, "appointmentscheduled")
```

## 📊 Google Analytics

### Configuração

**Variáveis de ambiente**:
```env
GA_MEASUREMENT_ID=G-XXXXXXXXXX
GA_API_SECRET=your_ga_api_secret
```

### Implementação

**Serviço Google Analytics**:
```python
import httpx
from typing import Dict, Any
from app.config import settings

class GoogleAnalyticsService:
    def __init__(self):
        self.measurement_id = settings.GA_MEASUREMENT_ID
        self.api_secret = settings.GA_API_SECRET
        self.base_url = "https://www.google-analytics.com/mp/collect"
    
    async def track_lead_event(self, lead: Dict[str, Any], event_name: str = "lead_created"):
        """Rastrear evento de lead no GA."""
        payload = {
            "client_id": f"lead_{lead['id']}",
            "events": [
                {
                    "name": event_name,
                    "params": {
                        "lead_id": lead["id"],
                        "lead_status": lead["status"],
                        "lead_score": lead["score"],
                        "lead_source": lead["origem"],
                        "lead_city": lead["cidade"],
                        "value": self._calculate_event_value(lead),
                        "currency": "BRL"
                    }
                }
            ]
        }
        
        params = {
            "measurement_id": self.measurement_id,
            "api_secret": self.api_secret
        }
        
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.base_url,
                    params=params,
                    json=payload
                )
                return response.status_code == 204
        except Exception as e:
            print(f"Erro ao enviar evento para GA: {e}")
            return False
    
    def _calculate_event_value(self, lead: Dict[str, Any]) -> float:
        """Calcular valor do evento baseado no score do lead."""
        # Valor base por score
        base_value = lead["score"] * 10
        
        # Multiplicador por status
        multipliers = {
            "QUENTE": 3.0,
            "MORNO": 2.0,
            "FRIO": 1.0
        }
        
        return base_value * multipliers.get(lead["status"], 1.0)
```

## 🔄 Webhooks de Entrada

### Meta Ads (Facebook/Instagram)

**Endpoint**: `POST /webhooks/meta-ads`

**Payload esperado**:
```json
{
  "entry": [
    {
      "id": "page_id",
      "time": 1642678800,
      "changes": [
        {
          "value": {
            "leadgen_id": "123456789",
            "page_id": "987654321",
            "form_id": "456789123",
            "adgroup_id": "789123456",
            "ad_id": "321654987",
            "created_time": "2024-01-15T10:30:00+0000"
          },
          "field": "leadgen"
        }
      ]
    }
  ]
}
```

**Implementação**:
```python
from fastapi import APIRouter, HTTPException, BackgroundTasks
from typing import Dict, Any

router = APIRouter(prefix="/webhooks", tags=["webhooks"])

@router.post("/meta-ads")
async def receive_meta_ads_webhook(
    payload: Dict[str, Any],
    background_tasks: BackgroundTasks
):
    """Receber webhook do Meta Ads."""
    try:
        for entry in payload.get("entry", []):
            for change in entry.get("changes", []):
                if change.get("field") == "leadgen":
                    leadgen_id = change["value"]["leadgen_id"]
                    
                    # Processar lead em background
                    background_tasks.add_task(
                        process_meta_ads_lead,
                        leadgen_id
                    )
        
        return {"status": "success"}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

async def process_meta_ads_lead(leadgen_id: str):
    """Processar lead do Meta Ads."""
    # Buscar dados do lead na API do Facebook
    lead_data = await fetch_meta_ads_lead_data(leadgen_id)
    
    if lead_data:
        # Converter para formato interno
        internal_lead = convert_meta_ads_to_internal(lead_data)
        
        # Criar lead no sistema
        await create_lead_from_webhook(internal_lead)
```

### Google Ads

**Configuração no Google Ads**:
1. Acessar Google Ads > Ferramentas > Configurações de conversão
2. Criar nova conversão tipo "Importação"
3. Configurar webhook: `https://api.empresa.com/webhooks/google-ads`

### RD Station

**Endpoint**: `POST /webhooks/rd-station`

**Headers necessários**:
```
X-RD-Signature: sha256=signature
Content-Type: application/json
```

## 📱 Integração com Apps Mobile

### React Native - SDK

**Instalação**:
```bash
npm install @streamleads/react-native-sdk
```

**Uso**:
```javascript
import StreamLeads from '@streamleads/react-native-sdk';

// Configurar SDK
StreamLeads.configure({
  apiUrl: 'https://api.empresa.com',
  apiKey: 'your_api_key'
});

// Enviar lead
const sendLead = async (leadData) => {
  try {
    const result = await StreamLeads.createLead({
      nome: leadData.name,
      email: leadData.email,
      telefone: leadData.phone,
      origem: 'MOBILE_APP',
      interesse: leadData.interest
    });
    
    console.log('Lead enviado:', result);
  } catch (error) {
    console.error('Erro ao enviar lead:', error);
  }
};
```

## 🔐 Segurança nas Integrações

### Autenticação

**API Keys**:
- Usar headers `X-API-Key`
- Rotacionar chaves regularmente
- Diferentes níveis de acesso

**OAuth 2.0**:
- Para integrações com Google, Facebook, HubSpot
- Refresh tokens automáticos
- Scopes mínimos necessários

### Validação de Webhooks

**Verificação de assinatura**:
```python
import hmac
import hashlib
from fastapi import HTTPException, Header

def verify_webhook_signature(
    payload: bytes,
    signature: str = Header(None, alias="X-Webhook-Signature"),
    secret: str = "webhook_secret"
) -> bool:
    """Verificar assinatura do webhook."""
    if not signature:
        raise HTTPException(status_code=401, detail="Signature missing")
    
    expected_signature = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    
    if not hmac.compare_digest(f"sha256={expected_signature}", signature):
        raise HTTPException(status_code=401, detail="Invalid signature")
    
    return True
```

### Rate Limiting

**Implementação**:
```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

@router.post("/webhooks/meta-ads")
@limiter.limit("100/minute")
async def receive_meta_ads_webhook(request: Request, ...):
    # Implementação do webhook
    pass
```

## 📊 Monitoramento de Integrações

### Métricas Importantes

- **Taxa de sucesso** por integração
- **Tempo de resposta** das APIs externas
- **Volume de leads** por origem
- **Erros de integração** por tipo

### Alertas

**Configuração no Grafana**:
```yaml
groups:
  - name: streamleads_integrations
    rules:
      - alert: IntegrationFailureRate
        expr: rate(integration_errors_total[5m]) > 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Alta taxa de erro em integrações"
          description: "Taxa de erro > 10% nos últimos 5 minutos"
      
      - alert: WebhookDown
        expr: up{job="webhook"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Webhook endpoint indisponível"
```

### Logs Estruturados

```python
import structlog

logger = structlog.get_logger()

async def log_integration_event(
    integration: str,
    event: str,
    lead_id: int = None,
    success: bool = True,
    error: str = None,
    duration_ms: int = None
):
    """Log estruturado para eventos de integração."""
    logger.info(
        "integration_event",
        integration=integration,
        event=event,
        lead_id=lead_id,
        success=success,
        error=error,
        duration_ms=duration_ms
    )
```

---

## 🚀 Próximos Passos

### Integrações Planejadas

1. **Zapier** - Conectar com 5000+ apps
2. **Pipedrive** - CRM alternativo
3. **Mailchimp** - Email marketing avançado
4. **Calendly** - Agendamento automático
5. **Twilio** - SMS e chamadas
6. **Zendesk** - Suporte ao cliente

### Melhorias

1. **Retry automático** com backoff exponencial
2. **Circuit breaker** para APIs instáveis
3. **Cache** de respostas de APIs
4. **Webhook replay** para falhas
5. **Dashboard** de status das integrações

---

**Documentação mantida por**: Equipe de Desenvolvimento StreamLeads  
**Última atualização**: Janeiro 2024  
**Versão**: 1.0.0