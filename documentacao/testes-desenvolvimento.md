# 🧪 Testes e Desenvolvimento - StreamLeads

## Visão Geral

Este documento descreve as estratégias de teste, configuração do ambiente de desenvolvimento e boas práticas para contribuir com o projeto StreamLeads.

## 🏗️ Configuração do Ambiente de Desenvolvimento

### 1. Pré-requisitos

**Software necessário**:
- Python 3.11+
- PostgreSQL 15+
- Redis 7+
- Docker & Docker Compose
- Git
- VS Code (recomendado)

### 2. Configuração Inicial

**Clone do repositório**:
```bash
git clone https://github.com/empresa/streamleads.git
cd streamleads
```

**Ambiente virtual**:
```bash
# Criar ambiente virtual
python -m venv venv

# Ativar (Windows)
venv\Scripts\activate

# Ativar (Linux/Mac)
source venv/bin/activate

# Instalar dependências
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

**Configuração do banco local**:
```bash
# Iniciar PostgreSQL e Redis com Docker
docker-compose -f docker-compose.dev.yml up -d db redis

# Criar banco de desenvolvimento
docker exec -it streamleads-db-dev createdb -U postgres streamleads_dev

# Executar migrações
alembic upgrade head

# Popular com dados de teste
python scripts/init_db.py
```

### 3. Configuração do VS Code

**.vscode/settings.json**:
```json
{
    "python.defaultInterpreterPath": "./venv/bin/python",
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": false,
    "python.linting.flake8Enabled": true,
    "python.linting.mypyEnabled": true,
    "python.formatting.provider": "black",
    "python.formatting.blackArgs": ["--line-length=88"],
    "python.sortImports.args": ["--profile", "black"],
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
        "source.organizeImports": true
    },
    "python.testing.pytestEnabled": true,
    "python.testing.pytestArgs": [
        "tests",
        "-v",
        "--tb=short"
    ],
    "files.exclude": {
        "**/__pycache__": true,
        "**/*.pyc": true,
        "**/venv": true,
        "**/.pytest_cache": true
    }
}
```

**.vscode/launch.json**:
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "FastAPI Dev Server",
            "type": "python",
            "request": "launch",
            "program": "-m",
            "args": ["uvicorn", "app.main:app", "--reload", "--host", "0.0.0.0", "--port", "8000"],
            "console": "integratedTerminal",
            "envFile": "${workspaceFolder}/.env",
            "cwd": "${workspaceFolder}"
        },
        {
            "name": "Streamlit Dashboard",
            "type": "python",
            "request": "launch",
            "program": "-m",
            "args": ["streamlit", "run", "dashboard/main.py", "--server.port", "8501"],
            "console": "integratedTerminal",
            "envFile": "${workspaceFolder}/.env",
            "cwd": "${workspaceFolder}"
        },
        {
            "name": "Run Tests",
            "type": "python",
            "request": "launch",
            "program": "-m",
            "args": ["pytest", "tests/", "-v"],
            "console": "integratedTerminal",
            "envFile": "${workspaceFolder}/.env.test",
            "cwd": "${workspaceFolder}"
        }
    ]
}
```

### 4. Docker Compose para Desenvolvimento

**docker-compose.dev.yml**:
```yaml
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: streamleads-db-dev
    environment:
      POSTGRES_DB: streamleads_dev
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_dev_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d streamleads_dev"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: streamleads-redis-dev
    ports:
      - "6379:6379"
    volumes:
      - redis_dev_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  mailhog:
    image: mailhog/mailhog:latest
    container_name: streamleads-mailhog
    ports:
      - "1025:1025"  # SMTP
      - "8025:8025"  # Web UI

volumes:
  postgres_dev_data:
  redis_dev_data:
```

## 🧪 Estratégia de Testes

### 1. Pirâmide de Testes

```
        /\     E2E Tests (5%)
       /  \    - Testes de interface
      /    \   - Fluxos completos
     /______\  
    /        \  Integration Tests (15%)
   /          \ - Testes de API
  /            \- Testes de banco
 /______________\
/                \ Unit Tests (80%)
\________________/ - Testes de lógica
                   - Testes de serviços
```

### 2. Configuração de Testes

**requirements-dev.txt**:
```txt
# Testes
pytest==7.4.3
pytest-asyncio==0.21.1
pytest-cov==4.1.0
pytest-mock==3.12.0
httpx==0.25.2
factory-boy==3.3.0
faker==20.1.0

# Linting e formatação
black==23.11.0
isort==5.12.0
flake8==6.1.0
mypy==1.7.1
bandit==1.7.5

# Desenvolvimento
pre-commit==3.6.0
watchdog==3.0.0
```

**pytest.ini**:
```ini
[tool:pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = 
    -v
    --tb=short
    --strict-markers
    --disable-warnings
    --cov=app
    --cov-report=term-missing
    --cov-report=html:htmlcov
    --cov-fail-under=80
markers =
    unit: Unit tests
    integration: Integration tests
    e2e: End-to-end tests
    slow: Slow running tests
    external: Tests that require external services
asyncio_mode = auto
```

**conftest.py**:
```python
import pytest
import asyncio
from typing import Generator, AsyncGenerator
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient
from httpx import AsyncClient

from app.main import app
from app.database import get_db, Base
from app.config import settings

# Configurar banco de teste
TEST_DATABASE_URL = "postgresql://postgres:postgres@localhost:5432/streamleads_test"
test_engine = create_engine(TEST_DATABASE_URL)
TestSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture(scope="function")
def db_session() -> Generator:
    """Create a fresh database session for each test."""
    # Criar todas as tabelas
    Base.metadata.create_all(bind=test_engine)
    
    session = TestSessionLocal()
    try:
        yield session
    finally:
        session.close()
        # Limpar todas as tabelas
        Base.metadata.drop_all(bind=test_engine)

@pytest.fixture(scope="function")
def client(db_session) -> Generator:
    """Create a test client with database dependency override."""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass
    
    app.dependency_overrides[get_db] = override_get_db
    
    with TestClient(app) as test_client:
        yield test_client
    
    app.dependency_overrides.clear()

@pytest.fixture(scope="function")
async def async_client(db_session) -> AsyncGenerator:
    """Create an async test client."""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass
    
    app.dependency_overrides[get_db] = override_get_db
    
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac
    
    app.dependency_overrides.clear()

@pytest.fixture
def sample_lead_data():
    """Sample lead data for testing."""
    return {
        "nome": "João Silva",
        "email": "joao@test.com",
        "telefone": "11999999999",
        "origem": "META_ADS",
        "interesse": "Apartamento na Zona Sul",
        "renda_aproximada": 8000.00,
        "cidade": "São Paulo"
    }
```

### 3. Factories para Testes

**tests/factories.py**:
```python
import factory
from factory.alchemy import SQLAlchemyModelFactory
from faker import Faker
from datetime import datetime

from app.models.lead import Lead, LeadStatus, LeadOrigin
from tests.conftest import TestSessionLocal

fake = Faker('pt_BR')

class LeadFactory(SQLAlchemyModelFactory):
    class Meta:
        model = Lead
        sqlalchemy_session = TestSessionLocal
        sqlalchemy_session_persistence = "commit"
    
    nome = factory.LazyAttribute(lambda obj: fake.name())
    email = factory.LazyAttribute(lambda obj: fake.email())
    telefone = factory.LazyAttribute(lambda obj: fake.phone_number())
    origem = factory.Iterator([origem.value for origem in LeadOrigin])
    interesse = factory.LazyAttribute(lambda obj: fake.text(max_nb_chars=100))
    renda_aproximada = factory.LazyAttribute(lambda obj: fake.random_int(min=1000, max=50000))
    cidade = factory.LazyAttribute(lambda obj: fake.city())
    score = factory.LazyAttribute(lambda obj: fake.random_int(min=0, max=40))
    status = factory.Iterator([status.value for status in LeadStatus])
    processado = "S"
    created_at = factory.LazyAttribute(lambda obj: fake.date_time_this_year())
    updated_at = factory.LazyAttribute(lambda obj: datetime.now())

class HotLeadFactory(LeadFactory):
    """Factory for hot leads."""
    interesse = "Apartamento para investimento"
    renda_aproximada = 15000
    cidade = "São Paulo"
    score = 35
    status = LeadStatus.QUENTE.value

class ColdLeadFactory(LeadFactory):
    """Factory for cold leads."""
    interesse = "Informações gerais"
    renda_aproximada = None
    cidade = "Interior"
    score = 10
    status = LeadStatus.FRIO.value
```

## 🔬 Testes Unitários

### 1. Testes de Modelos

**tests/unit/test_models.py**:
```python
import pytest
from datetime import datetime
from app.models.lead import Lead, LeadStatus, LeadOrigin

class TestLeadModel:
    def test_create_lead(self, db_session):
        """Test lead creation."""
        lead = Lead(
            nome="Test User",
            email="test@example.com",
            telefone="11999999999",
            origem=LeadOrigin.WEBSITE
        )
        
        db_session.add(lead)
        db_session.commit()
        
        assert lead.id is not None
        assert lead.nome == "Test User"
        assert lead.status == LeadStatus.PROCESSANDO
        assert lead.processado == "N"
        assert isinstance(lead.created_at, datetime)
    
    def test_lead_string_representation(self):
        """Test lead string representation."""
        lead = Lead(
            nome="Test User",
            email="test@example.com",
            telefone="11999999999",
            origem=LeadOrigin.WEBSITE
        )
        
        assert str(lead) == "Lead(Test User - test@example.com)"
    
    def test_lead_status_enum(self):
        """Test lead status enum values."""
        assert LeadStatus.QUENTE.value == "QUENTE"
        assert LeadStatus.MORNO.value == "MORNO"
        assert LeadStatus.FRIO.value == "FRIO"
        assert LeadStatus.PROCESSANDO.value == "PROCESSANDO"
```

### 2. Testes de Serviços

**tests/unit/test_scoring_service.py**:
```python
import pytest
from app.services.scoring import LeadScoringService
from app.models.lead import Lead, LeadOrigin, LeadStatus
from app.config import settings

class TestLeadScoringService:
    def setup_method(self):
        self.scoring_service = LeadScoringService()
    
    def test_calculate_required_fields_score(self):
        """Test required fields scoring."""
        # Lead com todos os campos obrigatórios
        lead_complete = Lead(
            nome="João Silva",
            email="joao@test.com",
            telefone="11999999999",
            origem=LeadOrigin.META_ADS
        )
        
        score = self.scoring_service._calculate_required_fields_score(lead_complete)
        assert score == settings.SCORE_CAMPOS_OBRIGATORIOS
        
        # Lead com campos faltando
        lead_incomplete = Lead(
            nome="",
            email="joao@test.com",
            telefone="11999999999",
            origem=LeadOrigin.META_ADS
        )
        
        score = self.scoring_service._calculate_required_fields_score(lead_incomplete)
        assert score == 0
    
    def test_calculate_high_ticket_score(self):
        """Test high ticket interest scoring."""
        # Lead com interesse em alto ticket
        lead_high_ticket = Lead(
            nome="João Silva",
            email="joao@test.com",
            telefone="11999999999",
            origem=LeadOrigin.META_ADS,
            interesse="Apartamento para investimento"
        )
        
        score = self.scoring_service._calculate_high_ticket_score(lead_high_ticket)
        assert score == settings.SCORE_INTERESSE_ALTO_TICKET
        
        # Lead sem interesse em alto ticket
        lead_low_ticket = Lead(
            nome="João Silva",
            email="joao@test.com",
            telefone="11999999999",
            origem=LeadOrigin.META_ADS,
            interesse="Informações gerais"
        )
        
        score = self.scoring_service._calculate_high_ticket_score(lead_low_ticket)
        assert score == 0
    
    def test_calculate_region_score(self):
        """Test region scoring."""
        # Lead de região atendida
        lead_served_region = Lead(
            nome="João Silva",
            email="joao@test.com",
            telefone="11999999999",
            origem=LeadOrigin.META_ADS,
            cidade="São Paulo"
        )
        
        score = self.scoring_service._calculate_region_score(lead_served_region)
        assert score == settings.SCORE_REGIAO_ATENDIDA
        
        # Lead de região não atendida
        lead_unserved_region = Lead(
            nome="João Silva",
            email="joao@test.com",
            telefone="11999999999",
            origem=LeadOrigin.META_ADS,
            cidade="Interior Distante"
        )
        
        score = self.scoring_service._calculate_region_score(lead_unserved_region)
        assert score == 0
    
    def test_calculate_income_bonus(self):
        """Test income bonus calculation."""
        test_cases = [
            (None, 0),
            (2000, 0),
            (4000, 2),
            (6000, 5),
            (10000, 8),
            (20000, 10)
        ]
        
        for renda, expected_score in test_cases:
            lead = Lead(
                nome="João Silva",
                email="joao@test.com",
                telefone="11999999999",
                origem=LeadOrigin.META_ADS,
                renda_aproximada=renda
            )
            
            score = self.scoring_service._calculate_income_bonus(lead)
            assert score == expected_score, f"Renda {renda} deveria retornar {expected_score}, mas retornou {score}"
    
    def test_classify_lead(self):
        """Test lead classification."""
        # Lead quente
        assert self.scoring_service.classify_lead(30) == LeadStatus.QUENTE
        
        # Lead morno
        assert self.scoring_service.classify_lead(20) == LeadStatus.MORNO
        
        # Lead frio
        assert self.scoring_service.classify_lead(10) == LeadStatus.FRIO
    
    def test_calculate_full_score(self):
        """Test complete score calculation."""
        lead = Lead(
            nome="Carlos Silva",
            email="carlos@test.com",
            telefone="11999999999",
            origem=LeadOrigin.META_ADS,
            interesse="Apartamento para investimento",
            renda_aproximada=12000,
            cidade="São Paulo"
        )
        
        score = self.scoring_service.calculate_score(lead)
        
        # Campos obrigatórios (10) + Alto ticket (15) + Região (5) + Renda (8) = 38
        expected_score = 10 + 15 + 5 + 8
        assert score == expected_score
```

### 3. Testes de Repositórios

**tests/unit/test_lead_repository.py**:
```python
import pytest
from datetime import datetime, timedelta
from app.repositories.lead_repository import LeadRepository
from app.schemas.lead import LeadCreate
from tests.factories import LeadFactory, HotLeadFactory, ColdLeadFactory

class TestLeadRepository:
    def setup_method(self, db_session):
        self.repo = LeadRepository(db_session)
        self.db = db_session
    
    def test_create_lead(self, db_session):
        """Test lead creation."""
        self.setup_method(db_session)
        
        lead_data = LeadCreate(
            nome="Test User",
            email="test@example.com",
            telefone="11999999999",
            origem="WEBSITE",
            interesse="Test interest",
            renda_aproximada=5000,
            cidade="São Paulo"
        )
        
        lead = self.repo.create(lead_data)
        
        assert lead.id is not None
        assert lead.nome == "Test User"
        assert lead.email == "test@example.com"
    
    def test_get_by_id(self, db_session):
        """Test get lead by ID."""
        self.setup_method(db_session)
        
        # Criar lead usando factory
        lead = LeadFactory()
        
        # Buscar por ID
        found_lead = self.repo.get_by_id(lead.id)
        
        assert found_lead is not None
        assert found_lead.id == lead.id
        assert found_lead.nome == lead.nome
    
    def test_get_by_email(self, db_session):
        """Test get lead by email."""
        self.setup_method(db_session)
        
        lead = LeadFactory(email="unique@test.com")
        
        found_lead = self.repo.get_by_email("unique@test.com")
        
        assert found_lead is not None
        assert found_lead.email == "unique@test.com"
    
    def test_get_leads_with_filters(self, db_session):
        """Test get leads with filters."""
        self.setup_method(db_session)
        
        # Criar leads de diferentes tipos
        hot_lead = HotLeadFactory()
        cold_lead = ColdLeadFactory()
        
        # Filtrar por status
        hot_leads = self.repo.get_leads(status="QUENTE")
        assert len(hot_leads) == 1
        assert hot_leads[0].id == hot_lead.id
        
        cold_leads = self.repo.get_leads(status="FRIO")
        assert len(cold_leads) == 1
        assert cold_leads[0].id == cold_lead.id
    
    def test_get_leads_for_followup(self, db_session):
        """Test get leads for follow-up."""
        self.setup_method(db_session)
        
        # Criar lead com follow-up vencido
        past_date = datetime.now() - timedelta(hours=1)
        lead_overdue = LeadFactory(follow_up_date=past_date)
        
        # Criar lead com follow-up futuro
        future_date = datetime.now() + timedelta(hours=1)
        lead_future = LeadFactory(follow_up_date=future_date)
        
        overdue_leads = self.repo.get_leads_for_followup()
        
        assert len(overdue_leads) == 1
        assert overdue_leads[0].id == lead_overdue.id
    
    def test_get_stats(self, db_session):
        """Test get general statistics."""
        self.setup_method(db_session)
        
        # Criar leads de diferentes tipos
        HotLeadFactory.create_batch(3)
        ColdLeadFactory.create_batch(2)
        
        stats = self.repo.get_stats()
        
        assert stats["total_leads"] == 5
        assert stats["leads_quentes"] == 3
        assert stats["leads_frios"] == 2
```

## 🔗 Testes de Integração

### 1. Testes de API

**tests/integration/test_leads_api.py**:
```python
import pytest
from httpx import AsyncClient
from app.models.lead import Lead
from tests.factories import LeadFactory

class TestLeadsAPI:
    @pytest.mark.asyncio
    async def test_create_lead(self, async_client: AsyncClient, sample_lead_data):
        """Test lead creation via API."""
        response = await async_client.post("/api/leads", json=sample_lead_data)
        
        assert response.status_code == 201
        data = response.json()
        assert data["nome"] == sample_lead_data["nome"]
        assert data["email"] == sample_lead_data["email"]
        assert "id" in data
        assert "score" in data
        assert "status" in data
    
    @pytest.mark.asyncio
    async def test_create_lead_duplicate_email(self, async_client: AsyncClient, sample_lead_data, db_session):
        """Test lead creation with duplicate email."""
        # Criar lead existente
        existing_lead = LeadFactory(email=sample_lead_data["email"])
        
        response = await async_client.post("/api/leads", json=sample_lead_data)
        
        assert response.status_code == 409
        data = response.json()
        assert "email já cadastrado" in data["detail"].lower()
    
    @pytest.mark.asyncio
    async def test_get_leads(self, async_client: AsyncClient, db_session):
        """Test get leads endpoint."""
        # Criar alguns leads
        LeadFactory.create_batch(5)
        
        response = await async_client.get("/api/leads")
        
        assert response.status_code == 200
        data = response.json()
        assert "leads" in data
        assert "total" in data
        assert len(data["leads"]) == 5
        assert data["total"] == 5
    
    @pytest.mark.asyncio
    async def test_get_leads_with_filters(self, async_client: AsyncClient, db_session):
        """Test get leads with filters."""
        # Criar leads de diferentes status
        hot_leads = LeadFactory.create_batch(3, status="QUENTE")
        cold_leads = LeadFactory.create_batch(2, status="FRIO")
        
        # Filtrar por status quente
        response = await async_client.get("/api/leads?status=QUENTE")
        
        assert response.status_code == 200
        data = response.json()
        assert len(data["leads"]) == 3
        assert all(lead["status"] == "QUENTE" for lead in data["leads"])
    
    @pytest.mark.asyncio
    async def test_get_lead_by_id(self, async_client: AsyncClient, db_session):
        """Test get specific lead."""
        lead = LeadFactory()
        
        response = await async_client.get(f"/api/leads/{lead.id}")
        
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == lead.id
        assert data["nome"] == lead.nome
    
    @pytest.mark.asyncio
    async def test_get_lead_not_found(self, async_client: AsyncClient):
        """Test get non-existent lead."""
        response = await async_client.get("/api/leads/99999")
        
        assert response.status_code == 404
    
    @pytest.mark.asyncio
    async def test_update_lead(self, async_client: AsyncClient, db_session):
        """Test lead update."""
        lead = LeadFactory()
        
        update_data = {
            "nome": "Nome Atualizado",
            "observacoes": "Observação de teste"
        }
        
        response = await async_client.put(f"/api/leads/{lead.id}", json=update_data)
        
        assert response.status_code == 200
        data = response.json()
        assert data["nome"] == "Nome Atualizado"
        assert data["observacoes"] == "Observação de teste"
    
    @pytest.mark.asyncio
    async def test_delete_lead(self, async_client: AsyncClient, db_session):
        """Test lead deletion."""
        lead = LeadFactory()
        
        response = await async_client.delete(f"/api/leads/{lead.id}")
        
        assert response.status_code == 200
        
        # Verificar se foi deletado
        get_response = await async_client.get(f"/api/leads/{lead.id}")
        assert get_response.status_code == 404
    
    @pytest.mark.asyncio
    async def test_get_scoring_explanation(self, async_client: AsyncClient, db_session):
        """Test scoring explanation endpoint."""
        lead = LeadFactory(
            interesse="Apartamento para investimento",
            cidade="São Paulo",
            renda_aproximada=10000
        )
        
        response = await async_client.get(f"/api/leads/{lead.id}/scoring-explanation")
        
        assert response.status_code == 200
        data = response.json()
        assert "score_total" in data
        assert "detalhes" in data
        assert "classificacao" in data
    
    @pytest.mark.asyncio
    async def test_reprocess_lead(self, async_client: AsyncClient, db_session):
        """Test lead reprocessing."""
        lead = LeadFactory()
        original_score = lead.score
        
        response = await async_client.post(f"/api/leads/{lead.id}/reprocess")
        
        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert "lead_id" in data
    
    @pytest.mark.asyncio
    async def test_get_stats(self, async_client: AsyncClient, db_session):
        """Test statistics endpoint."""
        # Criar leads de diferentes tipos
        LeadFactory.create_batch(3, status="QUENTE")
        LeadFactory.create_batch(2, status="MORNO")
        LeadFactory.create_batch(1, status="FRIO")
        
        response = await async_client.get("/api/leads/stats")
        
        assert response.status_code == 200
        data = response.json()
        assert data["total_leads"] == 6
        assert data["leads_quentes"] == 3
        assert data["leads_mornos"] == 2
        assert data["leads_frios"] == 1
```

### 2. Testes de Banco de Dados

**tests/integration/test_database.py**:
```python
import pytest
from sqlalchemy import text
from app.database import engine, get_db
from app.models.lead import Lead

class TestDatabase:
    def test_database_connection(self):
        """Test database connection."""
        with engine.connect() as connection:
            result = connection.execute(text("SELECT 1"))
            assert result.fetchone()[0] == 1
    
    def test_database_session(self, db_session):
        """Test database session."""
        # Criar um lead
        lead = Lead(
            nome="Test User",
            email="test@example.com",
            telefone="11999999999",
            origem="WEBSITE"
        )
        
        db_session.add(lead)
        db_session.commit()
        
        # Verificar se foi salvo
        saved_lead = db_session.query(Lead).filter(Lead.email == "test@example.com").first()
        assert saved_lead is not None
        assert saved_lead.nome == "Test User"
    
    def test_database_constraints(self, db_session):
        """Test database constraints."""
        # Criar lead
        lead1 = Lead(
            nome="User 1",
            email="unique@example.com",
            telefone="11999999999",
            origem="WEBSITE"
        )
        db_session.add(lead1)
        db_session.commit()
        
        # Tentar criar outro lead com mesmo email
        lead2 = Lead(
            nome="User 2",
            email="unique@example.com",
            telefone="11888888888",
            origem="META_ADS"
        )
        db_session.add(lead2)
        
        with pytest.raises(Exception):  # Deve falhar por violação de constraint
            db_session.commit()
```

## 🎭 Testes End-to-End

### 1. Testes de Fluxo Completo

**tests/e2e/test_lead_flow.py**:
```python
import pytest
from httpx import AsyncClient
from unittest.mock import patch, AsyncMock

class TestLeadFlow:
    @pytest.mark.e2e
    @pytest.mark.asyncio
    async def test_complete_lead_flow(self, async_client: AsyncClient):
        """Test complete lead processing flow."""
        # Dados do lead
        lead_data = {
            "nome": "Carlos Silva",
            "email": "carlos@test.com",
            "telefone": "11999999999",
            "origem": "META_ADS",
            "interesse": "Apartamento para investimento",
            "renda_aproximada": 15000,
            "cidade": "São Paulo"
        }
        
        # Mock das automações externas
        with patch('app.services.automation.AutomationService._send_slack_notification', new_callable=AsyncMock) as mock_slack, \
             patch('app.services.automation.AutomationService._send_to_n8n', new_callable=AsyncMock) as mock_n8n:
            
            # 1. Criar lead
            response = await async_client.post("/api/leads", json=lead_data)
            assert response.status_code == 201
            
            lead = response.json()
            lead_id = lead["id"]
            
            # 2. Verificar scoring
            assert lead["score"] >= 25  # Deve ser lead quente
            assert lead["status"] == "QUENTE"
            
            # 3. Verificar se automações foram chamadas
            mock_slack.assert_called_once()
            mock_n8n.assert_called_once()
            
            # 4. Buscar lead criado
            get_response = await async_client.get(f"/api/leads/{lead_id}")
            assert get_response.status_code == 200
            
            # 5. Atualizar lead
            update_data = {"observacoes": "Cliente muito interessado"}
            update_response = await async_client.put(f"/api/leads/{lead_id}", json=update_data)
            assert update_response.status_code == 200
            
            # 6. Verificar explicação de scoring
            scoring_response = await async_client.get(f"/api/leads/{lead_id}/scoring-explanation")
            assert scoring_response.status_code == 200
            
            scoring_data = scoring_response.json()
            assert scoring_data["score_total"] >= 25
            assert scoring_data["classificacao"] == "QUENTE"
    
    @pytest.mark.e2e
    @pytest.mark.asyncio
    async def test_cold_lead_flow(self, async_client: AsyncClient):
        """Test cold lead processing flow."""
        lead_data = {
            "nome": "João Santos",
            "email": "joao@test.com",
            "telefone": "11777777777",
            "origem": "WHATSAPP",
            "interesse": "Dúvidas gerais",
            "cidade": "Interior"
        }
        
        with patch('app.services.automation.AutomationService._send_to_n8n', new_callable=AsyncMock) as mock_n8n:
            # Criar lead
            response = await async_client.post("/api/leads", json=lead_data)
            assert response.status_code == 201
            
            lead = response.json()
            
            # Verificar classificação
            assert lead["score"] < 15
            assert lead["status"] == "FRIO"
            
            # Verificar automações (deve enviar para CRM)
            mock_n8n.assert_called()
    
    @pytest.mark.e2e
    @pytest.mark.asyncio
    async def test_statistics_flow(self, async_client: AsyncClient):
        """Test statistics generation flow."""
        # Criar vários leads
        leads_data = [
            {
                "nome": f"User {i}",
                "email": f"user{i}@test.com",
                "telefone": f"1199999999{i}",
                "origem": "META_ADS",
                "interesse": "Apartamento" if i % 2 == 0 else "Informações",
                "renda_aproximada": 10000 if i % 2 == 0 else 3000,
                "cidade": "São Paulo"
            }
            for i in range(10)
        ]
        
        # Criar todos os leads
        for lead_data in leads_data:
            response = await async_client.post("/api/leads", json=lead_data)
            assert response.status_code == 201
        
        # Verificar estatísticas gerais
        stats_response = await async_client.get("/api/leads/stats")
        assert stats_response.status_code == 200
        
        stats = stats_response.json()
        assert stats["total_leads"] == 10
        assert stats["leads_quentes"] > 0
        
        # Verificar estatísticas por origem
        origem_stats_response = await async_client.get("/api/leads/stats/origem")
        assert origem_stats_response.status_code == 200
        
        origem_stats = origem_stats_response.json()
        assert "META_ADS" in origem_stats
        assert origem_stats["META_ADS"]["total"] == 10
```

## 🔧 Ferramentas de Desenvolvimento

### 1. Pre-commit Hooks

**.pre-commit-config.yaml**:
```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict
  
  - repo: https://github.com/psf/black
    rev: 23.11.0
    hooks:
      - id: black
        language_version: python3.11
  
  - repo: https://github.com/pycqa/isort
    rev: 5.12.0
    hooks:
      - id: isort
        args: ["--profile", "black"]
  
  - repo: https://github.com/pycqa/flake8
    rev: 6.1.0
    hooks:
      - id: flake8
        args: ["--max-line-length=88", "--extend-ignore=E203,W503"]
  
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.7.1
    hooks:
      - id: mypy
        additional_dependencies: [types-all]
  
  - repo: https://github.com/pycqa/bandit
    rev: 1.7.5
    hooks:
      - id: bandit
        args: ["-r", "app/"]
```

### 2. Makefile para Automação

**Makefile**:
```makefile
.PHONY: help install test lint format clean dev prod backup

help:
	@echo "Comandos disponíveis:"
	@echo "  install     - Instalar dependências"
	@echo "  test        - Executar todos os testes"
	@echo "  test-unit   - Executar testes unitários"
	@echo "  test-int    - Executar testes de integração"
	@echo "  test-e2e    - Executar testes end-to-end"
	@echo "  lint        - Executar linting"
	@echo "  format      - Formatar código"
	@echo "  clean       - Limpar arquivos temporários"
	@echo "  dev         - Iniciar ambiente de desenvolvimento"
	@echo "  prod        - Deploy em produção"
	@echo "  backup      - Fazer backup do banco"

install:
	pip install -r requirements.txt
	pip install -r requirements-dev.txt
	pre-commit install

test:
	pytest tests/ -v --cov=app --cov-report=html

test-unit:
	pytest tests/unit/ -v -m "unit"

test-int:
	pytest tests/integration/ -v -m "integration"

test-e2e:
	pytest tests/e2e/ -v -m "e2e"

test-watch:
	pytest-watch tests/ -- -v

lint:
	flake8 app/ tests/
	mypy app/
	bandit -r app/

format:
	black app/ tests/
	isort app/ tests/

clean:
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	find . -type d -name ".pytest_cache" -delete
	rm -rf htmlcov/
	rm -rf .coverage

dev:
	docker-compose -f docker-compose.dev.yml up -d
	uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

dev-dashboard:
	streamlit run dashboard/main.py --server.port 8501

prod:
	docker-compose -f docker-compose.prod.yml up -d

backup:
	docker-compose -f docker-compose.prod.yml --profile backup up backup

migration:
	alembic revision --autogenerate -m "$(msg)"

migrate:
	alembic upgrade head

seed:
	python scripts/init_db.py
```

### 3. Scripts de Desenvolvimento

**scripts/dev-setup.sh**:
```bash
#!/bin/bash

echo "🚀 Configurando ambiente de desenvolvimento StreamLeads..."

# Verificar Python
if ! command -v python3.11 &> /dev/null; then
    echo "❌ Python 3.11 não encontrado. Instale antes de continuar."
    exit 1
fi

# Criar ambiente virtual
echo "📦 Criando ambiente virtual..."
python3.11 -m venv venv
source venv/bin/activate

# Instalar dependências
echo "📥 Instalando dependências..."
pip install --upgrade pip
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Configurar pre-commit
echo "🔧 Configurando pre-commit hooks..."
pre-commit install

# Iniciar serviços Docker
echo "🐳 Iniciando serviços Docker..."
docker-compose -f docker-compose.dev.yml up -d

# Aguardar serviços
echo "⏳ Aguardando serviços iniciarem..."
sleep 10

# Executar migrações
echo "🗃️ Executando migrações..."
alembic upgrade head

# Popular banco com dados de teste
echo "🌱 Populando banco com dados de teste..."
python scripts/init_db.py

# Executar testes
echo "🧪 Executando testes..."
pytest tests/ -v

echo "✅ Ambiente de desenvolvimento configurado com sucesso!"
echo "📝 Para iniciar o desenvolvimento:"
echo "   - API: make dev"
echo "   - Dashboard: make dev-dashboard"
echo "   - Testes: make test"
```

## 📊 Cobertura de Testes

### Configuração de Cobertura

**.coveragerc**:
```ini
[run]
source = app
omit = 
    app/__init__.py
    app/main.py
    */tests/*
    */venv/*
    */migrations/*

[report]
exclude_lines =
    pragma: no cover
    def __repr__
    raise AssertionError
    raise NotImplementedError
    if __name__ == .__main__.:
    class .*\(Protocol\):
    @(abc\.)?abstractmethod

[html]
directory = htmlcov
```

### Metas de Cobertura

- **Geral**: ≥ 80%
- **Serviços**: ≥ 90%
- **Repositórios**: ≥ 85%
- **APIs**: ≥ 75%
- **Modelos**: ≥ 95%

---

## 📋 Checklist de Desenvolvimento

### Antes de Commitar
- [ ] Testes passando
- [ ] Cobertura adequada
- [ ] Linting sem erros
- [ ] Documentação atualizada
- [ ] Pre-commit hooks executados

### Antes de Fazer PR
- [ ] Branch atualizada com main
- [ ] Testes de integração passando
- [ ] Descrição clara das mudanças
- [ ] Screenshots (se aplicável)
- [ ] Revisão de código própria

### Antes de Deploy
- [ ] Todos os testes passando
- [ ] Backup do banco
- [ ] Variáveis de ambiente verificadas
- [ ] Monitoramento configurado
- [ ] Rollback plan definido

---

**Documentação mantida por**: Equipe de Desenvolvimento StreamLeads  
**Última atualização**: Janeiro 2024  
**Versão**: 1.0.0