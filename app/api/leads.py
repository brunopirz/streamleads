from fastapi import APIRouter, Depends, HTTPException, Query, BackgroundTasks
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import date
import math

from app.database import get_db
from app.schemas.lead import (
    LeadCreate, LeadUpdate, LeadResponse, LeadListResponse, LeadStats
)
from app.models.lead import LeadStatus, LeadOrigin
from app.repositories.lead_repository import LeadRepository
from app.services.scoring import LeadScoringService
from app.services.automation import AutomationService
from loguru import logger

router = APIRouter(prefix="/leads", tags=["leads"])


def process_lead_background(lead_id: int, db: Session):
    """Processa lead em background"""
    try:
        repo = LeadRepository(db)
        scoring_service = LeadScoringService()
        automation_service = AutomationService()
        
        # Buscar lead
        lead = repo.get_by_id(lead_id)
        if not lead:
            logger.error(f"Lead {lead_id} não encontrado para processamento")
            return
        
        # Processar scoring
        lead = scoring_service.process_lead(lead)
        
        # Atualizar no banco
        repo.db.commit()
        
        # Executar automações
        automation_result = automation_service.process_lead_actions(lead)
        logger.info(f"Automações executadas para lead {lead_id}: {automation_result}")
        
    except Exception as e:
        logger.error(f"Erro no processamento em background do lead {lead_id}: {str(e)}")
        db.rollback()
    finally:
        db.close()


@router.post("/", response_model=LeadResponse, status_code=201)
async def create_lead(
    lead_data: LeadCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """
    Cria um novo lead e processa automaticamente o scoring e automações.
    
    - **nome**: Nome completo do lead
    - **email**: Email válido do lead
    - **telefone**: Telefone com DDD (10 ou 11 dígitos)
    - **origem**: Origem do lead (Meta Ads, Google Ads, etc.)
    - **interesse**: Descrição do interesse (opcional)
    - **renda_aproximada**: Renda mensal aproximada (opcional)
    - **cidade**: Cidade do lead (opcional)
    """
    try:
        repo = LeadRepository(db)
        
        # Verificar se já existe lead com mesmo email
        existing_lead = repo.get_by_email(lead_data.email)
        if existing_lead:
            raise HTTPException(
                status_code=400,
                detail=f"Já existe um lead cadastrado com o email {lead_data.email}"
            )
        
        # Criar lead
        lead = repo.create(lead_data)
        
        # Processar em background
        background_tasks.add_task(process_lead_background, lead.id, db)
        
        logger.info(f"Lead criado e enviado para processamento - ID: {lead.id}")
        return lead
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao criar lead: {str(e)}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.get("/", response_model=LeadListResponse)
async def list_leads(
    page: int = Query(1, ge=1, description="Número da página"),
    per_page: int = Query(20, ge=1, le=100, description="Itens por página"),
    status: Optional[LeadStatus] = Query(None, description="Filtrar por status"),
    origem: Optional[LeadOrigin] = Query(None, description="Filtrar por origem"),
    cidade: Optional[str] = Query(None, description="Filtrar por cidade"),
    data_inicio: Optional[date] = Query(None, description="Data início (YYYY-MM-DD)"),
    data_fim: Optional[date] = Query(None, description="Data fim (YYYY-MM-DD)"),
    search: Optional[str] = Query(None, description="Buscar por nome, email ou telefone"),
    db: Session = Depends(get_db)
):
    """
    Lista leads com filtros e paginação.
    
    Filtros disponíveis:
    - **status**: quente, morno, frio, processando
    - **origem**: Meta Ads, Google Ads, WhatsApp, Site, Indicação, Outros
    - **cidade**: Nome da cidade
    - **data_inicio/data_fim**: Período de criação
    - **search**: Busca por nome, email ou telefone
    """
    try:
        repo = LeadRepository(db)
        
        skip = (page - 1) * per_page
        
        leads, total = repo.get_all(
            skip=skip,
            limit=per_page,
            status=status,
            origem=origem,
            cidade=cidade,
            data_inicio=data_inicio,
            data_fim=data_fim,
            search=search
        )
        
        total_pages = math.ceil(total / per_page) if total > 0 else 1
        
        return LeadListResponse(
            leads=leads,
            total=total,
            page=page,
            per_page=per_page,
            total_pages=total_pages
        )
        
    except Exception as e:
        logger.error(f"Erro ao listar leads: {str(e)}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.get("/{lead_id}", response_model=LeadResponse)
async def get_lead(lead_id: int, db: Session = Depends(get_db)):
    """
    Busca um lead específico por ID.
    """
    try:
        repo = LeadRepository(db)
        lead = repo.get_by_id(lead_id)
        
        if not lead:
            raise HTTPException(status_code=404, detail="Lead não encontrado")
        
        return lead
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao buscar lead {lead_id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.put("/{lead_id}", response_model=LeadResponse)
async def update_lead(
    lead_id: int,
    lead_data: LeadUpdate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """
    Atualiza informações de um lead.
    
    Se dados relevantes para scoring forem alterados, o lead será reprocessado.
    """
    try:
        repo = LeadRepository(db)
        
        # Verificar se lead existe
        existing_lead = repo.get_by_id(lead_id)
        if not existing_lead:
            raise HTTPException(status_code=404, detail="Lead não encontrado")
        
        # Verificar email duplicado se email for alterado
        if lead_data.email and lead_data.email != existing_lead.email:
            email_exists = repo.get_by_email(lead_data.email)
            if email_exists:
                raise HTTPException(
                    status_code=400,
                    detail=f"Já existe um lead cadastrado com o email {lead_data.email}"
                )
        
        # Atualizar lead
        updated_lead = repo.update(lead_id, lead_data)
        
        # Se campos relevantes para scoring foram alterados, reprocessar
        scoring_fields = ['interesse', 'renda_aproximada', 'cidade']
        if any(getattr(lead_data, field, None) is not None for field in scoring_fields):
            background_tasks.add_task(process_lead_background, lead_id, db)
            logger.info(f"Lead {lead_id} enviado para reprocessamento após atualização")
        
        return updated_lead
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao atualizar lead {lead_id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.delete("/{lead_id}", status_code=204)
async def delete_lead(lead_id: int, db: Session = Depends(get_db)):
    """
    Deleta um lead.
    """
    try:
        repo = LeadRepository(db)
        
        success = repo.delete(lead_id)
        if not success:
            raise HTTPException(status_code=404, detail="Lead não encontrado")
        
        logger.info(f"Lead {lead_id} deletado com sucesso")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao deletar lead {lead_id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.get("/{lead_id}/scoring", response_model=dict)
async def get_lead_scoring_explanation(
    lead_id: int,
    db: Session = Depends(get_db)
):
    """
    Retorna explicação detalhada do scoring de um lead.
    """
    try:
        repo = LeadRepository(db)
        lead = repo.get_by_id(lead_id)
        
        if not lead:
            raise HTTPException(status_code=404, detail="Lead não encontrado")
        
        scoring_service = LeadScoringService()
        explanation = scoring_service.get_scoring_explanation(lead)
        
        return explanation
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao buscar explicação de scoring do lead {lead_id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.post("/{lead_id}/reprocess", response_model=dict)
async def reprocess_lead(
    lead_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db)
):
    """
    Reprocessa um lead (recalcula scoring e executa automações).
    """
    try:
        repo = LeadRepository(db)
        lead = repo.get_by_id(lead_id)
        
        if not lead:
            raise HTTPException(status_code=404, detail="Lead não encontrado")
        
        # Marcar como não processado
        lead.processado = "N"
        db.commit()
        
        # Processar em background
        background_tasks.add_task(process_lead_background, lead_id, db)
        
        return {
            "message": f"Lead {lead_id} enviado para reprocessamento",
            "lead_id": lead_id
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao reprocessar lead {lead_id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.get("/stats/overview", response_model=LeadStats)
async def get_leads_stats(db: Session = Depends(get_db)):
    """
    Retorna estatísticas gerais dos leads.
    """
    try:
        repo = LeadRepository(db)
        stats = repo.get_stats()
        return LeadStats(**stats)
        
    except Exception as e:
        logger.error(f"Erro ao buscar estatísticas: {str(e)}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.get("/stats/origem", response_model=dict)
async def get_leads_by_origem(db: Session = Depends(get_db)):
    """
    Retorna contagem de leads por origem.
    """
    try:
        repo = LeadRepository(db)
        stats = repo.get_leads_by_origem()
        return {"leads_por_origem": stats}
        
    except Exception as e:
        logger.error(f"Erro ao buscar leads por origem: {str(e)}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor")


@router.get("/stats/periodo", response_model=dict)
async def get_leads_by_period(
    days: int = Query(30, ge=1, le=365, description="Número de dias"),
    db: Session = Depends(get_db)
):
    """
    Retorna leads agrupados por data dos últimos N dias.
    """
    try:
        repo = LeadRepository(db)
        stats = repo.get_leads_by_period(days)
        return {"leads_por_periodo": stats}
        
    except Exception as e:
        logger.error(f"Erro ao buscar leads por período: {str(e)}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor")