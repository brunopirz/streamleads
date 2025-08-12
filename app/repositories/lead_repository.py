from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_
from app.models.lead import Lead, LeadStatus, LeadOrigin
from app.schemas.lead import LeadCreate, LeadUpdate
from datetime import datetime, date
from typing import List, Optional, Tuple
from loguru import logger


class LeadRepository:
    """Repositório para operações de banco de dados com leads"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def create(self, lead_data: LeadCreate) -> Lead:
        """Cria um novo lead"""
        try:
            lead = Lead(**lead_data.model_dump())
            self.db.add(lead)
            self.db.commit()
            self.db.refresh(lead)
            
            logger.info(f"Lead criado com sucesso - ID: {lead.id}, Nome: {lead.nome}")
            return lead
            
        except Exception as e:
            self.db.rollback()
            logger.error(f"Erro ao criar lead: {str(e)}")
            raise
    
    def get_by_id(self, lead_id: int) -> Optional[Lead]:
        """Busca lead por ID"""
        return self.db.query(Lead).filter(Lead.id == lead_id).first()
    
    def get_by_email(self, email: str) -> Optional[Lead]:
        """Busca lead por email"""
        return self.db.query(Lead).filter(Lead.email == email).first()
    
    def update(self, lead_id: int, lead_data: LeadUpdate) -> Optional[Lead]:
        """Atualiza um lead"""
        try:
            lead = self.get_by_id(lead_id)
            if not lead:
                return None
            
            # Atualiza apenas campos não nulos
            update_data = lead_data.model_dump(exclude_unset=True)
            for field, value in update_data.items():
                setattr(lead, field, value)
            
            lead.updated_at = datetime.now()
            self.db.commit()
            self.db.refresh(lead)
            
            logger.info(f"Lead atualizado - ID: {lead.id}, Campos: {list(update_data.keys())}")
            return lead
            
        except Exception as e:
            self.db.rollback()
            logger.error(f"Erro ao atualizar lead {lead_id}: {str(e)}")
            raise
    
    def delete(self, lead_id: int) -> bool:
        """Deleta um lead"""
        try:
            lead = self.get_by_id(lead_id)
            if not lead:
                return False
            
            self.db.delete(lead)
            self.db.commit()
            
            logger.info(f"Lead deletado - ID: {lead_id}")
            return True
            
        except Exception as e:
            self.db.rollback()
            logger.error(f"Erro ao deletar lead {lead_id}: {str(e)}")
            raise
    
    def get_all(
        self,
        skip: int = 0,
        limit: int = 100,
        status: Optional[LeadStatus] = None,
        origem: Optional[LeadOrigin] = None,
        cidade: Optional[str] = None,
        data_inicio: Optional[date] = None,
        data_fim: Optional[date] = None,
        search: Optional[str] = None
    ) -> Tuple[List[Lead], int]:
        """Lista leads com filtros e paginação"""
        query = self.db.query(Lead)
        
        # Aplicar filtros
        if status:
            query = query.filter(Lead.status == status)
        
        if origem:
            query = query.filter(Lead.origem == origem)
        
        if cidade:
            query = query.filter(Lead.cidade.ilike(f"%{cidade}%"))
        
        if data_inicio:
            query = query.filter(func.date(Lead.created_at) >= data_inicio)
        
        if data_fim:
            query = query.filter(func.date(Lead.created_at) <= data_fim)
        
        if search:
            search_filter = or_(
                Lead.nome.ilike(f"%{search}%"),
                Lead.email.ilike(f"%{search}%"),
                Lead.telefone.ilike(f"%{search}%"),
                Lead.interesse.ilike(f"%{search}%")
            )
            query = query.filter(search_filter)
        
        # Contar total
        total = query.count()
        
        # Aplicar paginação e ordenação
        leads = query.order_by(Lead.created_at.desc()).offset(skip).limit(limit).all()
        
        return leads, total
    
    def get_leads_for_follow_up(self, date_limit: datetime) -> List[Lead]:
        """Busca leads que precisam de follow-up"""
        return self.db.query(Lead).filter(
            and_(
                Lead.follow_up_date <= date_limit,
                Lead.follow_up_date.isnot(None)
            )
        ).all()
    
    def get_unprocessed_leads(self) -> List[Lead]:
        """Busca leads não processados"""
        return self.db.query(Lead).filter(Lead.processado == "N").all()
    
    def get_stats(self) -> dict:
        """Retorna estatísticas dos leads"""
        try:
            # Total de leads
            total_leads = self.db.query(Lead).count()
            
            # Leads por status
            leads_quentes = self.db.query(Lead).filter(Lead.status == LeadStatus.QUENTE).count()
            leads_mornos = self.db.query(Lead).filter(Lead.status == LeadStatus.MORNO).count()
            leads_frios = self.db.query(Lead).filter(Lead.status == LeadStatus.FRIO).count()
            leads_processando = self.db.query(Lead).filter(Lead.status == LeadStatus.PROCESSANDO).count()
            
            # Média de score
            media_score = self.db.query(func.avg(Lead.score)).scalar() or 0
            
            # Leads de hoje
            hoje = date.today()
            leads_hoje = self.db.query(Lead).filter(
                func.date(Lead.created_at) == hoje
            ).count()
            
            return {
                "total_leads": total_leads,
                "leads_quentes": leads_quentes,
                "leads_mornos": leads_mornos,
                "leads_frios": leads_frios,
                "leads_processando": leads_processando,
                "media_score": round(float(media_score), 2),
                "leads_hoje": leads_hoje
            }
            
        except Exception as e:
            logger.error(f"Erro ao buscar estatísticas: {str(e)}")
            return {
                "total_leads": 0,
                "leads_quentes": 0,
                "leads_mornos": 0,
                "leads_frios": 0,
                "leads_processando": 0,
                "media_score": 0.0,
                "leads_hoje": 0
            }
    
    def get_leads_by_origem(self) -> dict:
        """Retorna contagem de leads por origem"""
        try:
            result = self.db.query(
                Lead.origem,
                func.count(Lead.id).label('count')
            ).group_by(Lead.origem).all()
            
            return {origem.value: count for origem, count in result}
            
        except Exception as e:
            logger.error(f"Erro ao buscar leads por origem: {str(e)}")
            return {}
    
    def get_leads_by_period(self, days: int = 30) -> List[dict]:
        """Retorna leads agrupados por data dos últimos N dias"""
        try:
            from datetime import timedelta
            
            data_limite = datetime.now() - timedelta(days=days)
            
            result = self.db.query(
                func.date(Lead.created_at).label('data'),
                func.count(Lead.id).label('count')
            ).filter(
                Lead.created_at >= data_limite
            ).group_by(
                func.date(Lead.created_at)
            ).order_by(
                func.date(Lead.created_at)
            ).all()
            
            return [
                {
                    "data": data.strftime("%Y-%m-%d"),
                    "count": count
                }
                for data, count in result
            ]
            
        except Exception as e:
            logger.error(f"Erro ao buscar leads por período: {str(e)}")
            return []