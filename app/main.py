from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import uvicorn

from app.config import settings
from app.database import create_tables
from app.api.leads import router as leads_router
from loguru import logger
import sys

# Configurar logging
logger.remove()
logger.add(
    sys.stdout,
    format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>",
    level="INFO"
)
logger.add(
    "logs/streamleads.log",
    rotation="1 day",
    retention="30 days",
    format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {name}:{function}:{line} - {message}",
    level="INFO"
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Gerencia o ciclo de vida da aplicação"""
    # Startup
    logger.info("Iniciando StreamLeads API...")
    try:
        create_tables()
        logger.info("Tabelas do banco de dados criadas/verificadas")
    except Exception as e:
        logger.error(f"Erro ao criar tabelas: {str(e)}")
        raise
    
    logger.info("StreamLeads API iniciada com sucesso!")
    yield
    
    # Shutdown
    logger.info("Encerrando StreamLeads API...")


# Criar aplicação FastAPI
app = FastAPI(
    title="StreamLeads API",
    description="""
    Sistema de Automação de Leads - API para receber, processar e qualificar leads automaticamente.
    
    ## Funcionalidades
    
    * **Recebimento de Leads**: Endpoint para receber leads de múltiplas origens
    * **Scoring Automático**: Qualificação automática baseada em regras de negócio
    * **Automações**: Ações automáticas baseadas no status do lead
    * **Gestão Completa**: CRUD completo para gerenciar leads
    * **Estatísticas**: Dashboards e relatórios em tempo real
    
    ## Fluxo de Processamento
    
    1. **Recebimento**: Lead é recebido via POST /leads
    2. **Validação**: Dados são validados e lead é salvo no banco
    3. **Scoring**: Sistema calcula score baseado em regras configuráveis
    4. **Classificação**: Lead é classificado como Quente, Morno ou Frio
    5. **Automação**: Ações automáticas são executadas baseadas no status
    
    ## Regras de Scoring
    
    * **Campos obrigatórios preenchidos**: +10 pontos
    * **Interesse em produto de alto ticket**: +15 pontos
    * **Região atendida pela empresa**: +5 pontos
    * **Bônus por renda**: 0-10 pontos baseado na faixa de renda
    
    ## Classificação
    
    * **Lead Quente** (≥25 pontos): Enviado imediatamente para vendas
    * **Lead Morno** (15-24 pontos): Nutrição via email e follow-up
    * **Lead Frio** (<15 pontos): Inserido no CRM para follow-up futuro
    """,
    version="1.0.0",
    contact={
        "name": "StreamLeads Support",
        "email": "support@streamleads.com",
    },
    license_info={
        "name": "MIT",
    },
    lifespan=lifespan
)

# Configurar CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Em produção, especificar domínios específicos
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Incluir routers
app.include_router(leads_router, prefix="/api/v1")


@app.get("/", tags=["root"])
async def root():
    """Endpoint raiz da API"""
    return {
        "message": "StreamLeads API",
        "version": "1.0.0",
        "status": "online",
        "docs": "/docs",
        "redoc": "/redoc"
    }


@app.get("/health", tags=["health"])
async def health_check():
    """Endpoint para verificação de saúde da API"""
    try:
        from app.database import engine
        
        # Testar conexão com banco
        with engine.connect() as conn:
            conn.execute("SELECT 1")
        
        return {
            "status": "healthy",
            "database": "connected",
            "environment": settings.environment
        }
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        raise HTTPException(status_code=503, detail="Service unavailable")


@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Handler global para exceções não tratadas"""
    logger.error(f"Erro não tratado: {str(exc)}")
    return JSONResponse(
        status_code=500,
        content={"detail": "Erro interno do servidor"}
    )


if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host=settings.api_host,
        port=settings.api_port,
        reload=settings.debug,
        log_level="info"
    )