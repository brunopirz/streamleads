# 🚀 Documentação da API StreamLeads

## Visão Geral

A API StreamLeads é uma REST API construída com FastAPI que gerencia o ciclo completo de leads, desde o recebimento até a automação de ações baseadas na qualificação.

**Base URL**: `http://localhost:8000`  
**Documentação Interativa**: `http://localhost:8000/docs`  
**Esquema OpenAPI**: `http://localhost:8000/openapi.json`

## 📋 Endpoints Disponíveis

### 🏠 Endpoints Básicos

#### GET `/`
**Descrição**: Endpoint raiz da aplicação

**Resposta**:
```json
{
  "message": "StreamLeads API - Sistema de Automação de Leads",
  "version": "1.0.0",
  "docs": "/docs"
}
```

#### GET `/health`
**Descrição**: Verificação de saúde da aplicação

**Resposta**:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "database": "connected"
}
```

---

### 👥 Endpoints de Leads

#### POST `/api/leads`
**Descrição**: Cria um novo lead e processa automaticamente

**Headers**:
```
Content-Type: application/json
```

**Body**:
```json
{
  "nome": "João Silva",
  "email": "joao@email.com",
  "telefone": "11999999999",
  "origem": "META_ADS",
  "interesse": "Apartamento na Zona Sul",
  "renda_aproximada": 8000.00,
  "cidade": "São Paulo"
}
```

**Resposta de Sucesso (201)**:
```json
{
  "id": 1,
  "nome": "João Silva",
  "email": "joao@email.com",
  "telefone": "11999999999",
  "origem": "META_ADS",
  "interesse": "Apartamento na Zona Sul",
  "renda_aproximada": 8000.00,
  "cidade": "São Paulo",
  "score": 30,
  "status": "QUENTE",
  "processado": "S",
  "observacoes": null,
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z",
  "follow_up_date": "2024-01-15T11:30:00Z"
}
```

**Possíveis Erros**:
- `400`: Dados inválidos
- `409`: Email já cadastrado
- `500`: Erro interno do servidor

---

#### GET `/api/leads`
**Descrição**: Lista leads com filtros e paginação

**Query Parameters**:
- `status` (opcional): Filtrar por status (QUENTE, MORNO, FRIO)
- `origem` (opcional): Filtrar por origem
- `cidade` (opcional): Filtrar por cidade
- `data_inicio` (opcional): Data inicial (YYYY-MM-DD)
- `data_fim` (opcional): Data final (YYYY-MM-DD)
- `skip` (opcional): Número de registros para pular (padrão: 0)
- `limit` (opcional): Limite de registros (padrão: 100, máximo: 1000)

**Exemplo de Requisição**:
```
GET /api/leads?status=QUENTE&origem=META_ADS&skip=0&limit=10
```

**Resposta**:
```json
{
  "leads": [
    {
      "id": 1,
      "nome": "João Silva",
      "email": "joao@email.com",
      "telefone": "11999999999",
      "origem": "META_ADS",
      "interesse": "Apartamento na Zona Sul",
      "renda_aproximada": 8000.00,
      "cidade": "São Paulo",
      "score": 30,
      "status": "QUENTE",
      "processado": "S",
      "observacoes": null,
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z",
      "follow_up_date": "2024-01-15T11:30:00Z"
    }
  ],
  "total": 1,
  "skip": 0,
  "limit": 10
}
```

---

#### GET `/api/leads/{id}`
**Descrição**: Busca um lead específico por ID

**Path Parameters**:
- `id`: ID do lead (integer)

**Resposta de Sucesso (200)**:
```json
{
  "id": 1,
  "nome": "João Silva",
  "email": "joao@email.com",
  "telefone": "11999999999",
  "origem": "META_ADS",
  "interesse": "Apartamento na Zona Sul",
  "renda_aproximada": 8000.00,
  "cidade": "São Paulo",
  "score": 30,
  "status": "QUENTE",
  "processado": "S",
  "observacoes": null,
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:30:00Z",
  "follow_up_date": "2024-01-15T11:30:00Z"
}
```

**Possíveis Erros**:
- `404`: Lead não encontrado

---

#### PUT `/api/leads/{id}`
**Descrição**: Atualiza um lead existente

**Path Parameters**:
- `id`: ID do lead (integer)

**Body** (todos os campos são opcionais):
```json
{
  "nome": "João Silva Santos",
  "telefone": "11888888888",
  "interesse": "Casa na Zona Oeste",
  "renda_aproximada": 10000.00,
  "cidade": "São Paulo",
  "observacoes": "Cliente interessado em imóvel até R$ 500k"
}
```

**Resposta de Sucesso (200)**:
```json
{
  "id": 1,
  "nome": "João Silva Santos",
  "email": "joao@email.com",
  "telefone": "11888888888",
  "origem": "META_ADS",
  "interesse": "Casa na Zona Oeste",
  "renda_aproximada": 10000.00,
  "cidade": "São Paulo",
  "score": 30,
  "status": "QUENTE",
  "processado": "S",
  "observacoes": "Cliente interessado em imóvel até R$ 500k",
  "created_at": "2024-01-15T10:30:00Z",
  "updated_at": "2024-01-15T10:35:00Z",
  "follow_up_date": "2024-01-15T11:30:00Z"
}
```

**Possíveis Erros**:
- `404`: Lead não encontrado
- `400`: Dados inválidos

---

#### DELETE `/api/leads/{id}`
**Descrição**: Remove um lead do sistema

**Path Parameters**:
- `id`: ID do lead (integer)

**Resposta de Sucesso (200)**:
```json
{
  "message": "Lead removido com sucesso"
}
```

**Possíveis Erros**:
- `404`: Lead não encontrado

---

#### GET `/api/leads/{id}/scoring-explanation`
**Descrição**: Explica como o score do lead foi calculado

**Path Parameters**:
- `id`: ID do lead (integer)

**Resposta**:
```json
{
  "lead_id": 1,
  "score_total": 30,
  "detalhes": {
    "campos_obrigatorios": {
      "pontos": 10,
      "descricao": "Todos os campos obrigatórios preenchidos"
    },
    "interesse_alto_ticket": {
      "pontos": 15,
      "descricao": "Interesse em produto de alto valor detectado",
      "palavras_encontradas": ["apartamento"]
    },
    "regiao_atendida": {
      "pontos": 5,
      "descricao": "Cidade está na região atendida"
    },
    "bonus_renda": {
      "pontos": 0,
      "descricao": "Renda não informada ou abaixo do threshold"
    }
  },
  "classificacao": "QUENTE",
  "threshold_quente": 25,
  "threshold_morno": 15
}
```

---

#### POST `/api/leads/{id}/reprocess`
**Descrição**: Reprocessa o scoring e automações de um lead

**Path Parameters**:
- `id`: ID do lead (integer)

**Resposta**:
```json
{
  "message": "Lead reprocessado com sucesso",
  "lead_id": 1,
  "score_anterior": 25,
  "score_novo": 30,
  "status_anterior": "MORNO",
  "status_novo": "QUENTE"
}
```

---

### 📊 Endpoints de Estatísticas

#### GET `/api/leads/stats`
**Descrição**: Estatísticas gerais dos leads

**Resposta**:
```json
{
  "total_leads": 150,
  "leads_quentes": 45,
  "leads_mornos": 60,
  "leads_frios": 45,
  "taxa_conversao_quente": 30.0,
  "score_medio": 18.5,
  "leads_hoje": 12,
  "leads_semana": 78,
  "leads_mes": 150
}
```

#### GET `/api/leads/stats/origem`
**Descrição**: Estatísticas por origem dos leads

**Resposta**:
```json
{
  "META_ADS": {
    "total": 80,
    "quentes": 25,
    "mornos": 35,
    "frios": 20,
    "score_medio": 19.2
  },
  "GOOGLE_ADS": {
    "total": 45,
    "quentes": 15,
    "mornos": 20,
    "frios": 10,
    "score_medio": 17.8
  },
  "WHATSAPP": {
    "total": 25,
    "quentes": 5,
    "mornos": 5,
    "frios": 15,
    "score_medio": 14.3
  }
}
```

#### GET `/api/leads/stats/periodo`
**Descrição**: Estatísticas por período

**Query Parameters**:
- `periodo`: Tipo de agrupamento (dia, semana, mes)
- `limite`: Número de períodos (padrão: 30)

**Exemplo**: `GET /api/leads/stats/periodo?periodo=dia&limite=7`

**Resposta**:
```json
{
  "periodo": "dia",
  "dados": [
    {
      "data": "2024-01-15",
      "total": 12,
      "quentes": 4,
      "mornos": 5,
      "frios": 3
    },
    {
      "data": "2024-01-14",
      "total": 8,
      "quentes": 2,
      "mornos": 4,
      "frios": 2
    }
  ]
}
```

---

## 🔧 Códigos de Status HTTP

| Código | Descrição |
|--------|----------|
| 200 | Sucesso |
| 201 | Criado com sucesso |
| 400 | Requisição inválida |
| 404 | Recurso não encontrado |
| 409 | Conflito (ex: email duplicado) |
| 422 | Erro de validação |
| 500 | Erro interno do servidor |

---

## 📝 Schemas de Dados

### LeadCreate
```json
{
  "nome": "string (obrigatório, min: 2, max: 255)",
  "email": "string (obrigatório, formato email)",
  "telefone": "string (obrigatório, formato brasileiro)",
  "origem": "enum (obrigatório): WEBSITE|META_ADS|GOOGLE_ADS|WHATSAPP|INDICACAO|OUTROS",
  "interesse": "string (opcional, max: 500)",
  "renda_aproximada": "number (opcional, min: 0)",
  "cidade": "string (opcional, max: 100)"
}
```

### LeadUpdate
```json
{
  "nome": "string (opcional, min: 2, max: 255)",
  "telefone": "string (opcional, formato brasileiro)",
  "interesse": "string (opcional, max: 500)",
  "renda_aproximada": "number (opcional, min: 0)",
  "cidade": "string (opcional, max: 100)",
  "observacoes": "string (opcional, max: 1000)"
}
```

### LeadResponse
```json
{
  "id": "integer",
  "nome": "string",
  "email": "string",
  "telefone": "string",
  "origem": "string",
  "interesse": "string|null",
  "renda_aproximada": "number|null",
  "cidade": "string|null",
  "score": "integer",
  "status": "enum: QUENTE|MORNO|FRIO|PROCESSANDO",
  "processado": "string: S|N",
  "observacoes": "string|null",
  "created_at": "datetime",
  "updated_at": "datetime|null",
  "follow_up_date": "datetime|null"
}
```

---

## 🧪 Exemplos de Uso

### Criar Lead com cURL
```bash
curl -X POST "http://localhost:8000/api/leads" \
  -H "Content-Type: application/json" \
  -d '{
    "nome": "Maria Santos",
    "email": "maria@email.com",
    "telefone": "11987654321",
    "origem": "WEBSITE",
    "interesse": "Investimento em imóveis",
    "renda_aproximada": 12000,
    "cidade": "São Paulo"
  }'
```

### Buscar Leads com Python
```python
import requests

response = requests.get(
    "http://localhost:8000/api/leads",
    params={
        "status": "QUENTE",
        "origem": "META_ADS",
        "limit": 50
    }
)

leads = response.json()
print(f"Total de leads: {leads['total']}")
```

### Atualizar Lead com JavaScript
```javascript
fetch('http://localhost:8000/api/leads/1', {
  method: 'PUT',
  headers: {
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    observacoes: 'Cliente muito interessado, agendar visita'
  })
})
.then(response => response.json())
.then(data => console.log(data));
```

---

## 🔍 Filtros Avançados

### Busca por Período
```
GET /api/leads?data_inicio=2024-01-01&data_fim=2024-01-31
```

### Múltiplos Filtros
```
GET /api/leads?status=QUENTE&origem=META_ADS&cidade=São Paulo&limit=20
```

### Paginação
```
GET /api/leads?skip=100&limit=50  # Página 3 (50 por página)
```

---

## ⚠️ Limitações e Considerações

### Rate Limiting
- **Produção**: 100 requisições por minuto por IP
- **Desenvolvimento**: Sem limite

### Tamanho de Payload
- **Máximo**: 1MB por requisição
- **Recomendado**: < 100KB

### Timeout
- **Requisições**: 30 segundos
- **Background tasks**: 5 minutos

### Validações
- **Email**: Deve ser único no sistema
- **Telefone**: Formato brasileiro (11 dígitos)
- **Nome**: Mínimo 2 caracteres

---

## 🐛 Tratamento de Erros

### Formato Padrão de Erro
```json
{
  "detail": "Descrição do erro",
  "error_code": "VALIDATION_ERROR",
  "timestamp": "2024-01-15T10:30:00Z",
  "path": "/api/leads"
}
```

### Códigos de Erro Comuns
- `VALIDATION_ERROR`: Dados inválidos
- `DUPLICATE_EMAIL`: Email já cadastrado
- `LEAD_NOT_FOUND`: Lead não encontrado
- `PROCESSING_ERROR`: Erro no processamento
- `EXTERNAL_SERVICE_ERROR`: Erro em serviço externo

---

**Documentação mantida por**: Equipe de Desenvolvimento StreamLeads  
**Última atualização**: Janeiro 2024  
**Versão da API**: 1.0.0