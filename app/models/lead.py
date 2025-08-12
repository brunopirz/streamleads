from sqlalchemy import Column, Integer, String, Float, DateTime, Text, Enum
from sqlalchemy.sql import func
from app.database import Base
import enum


class LeadStatus(str, enum.Enum):
    """Enum para status do lead"""
    QUENTE = "quente"
    MORNO = "morno"
    FRIO = "frio"
    PROCESSANDO = "processando"


class LeadOrigin(str, enum.Enum):
    """Enum para origem do lead"""
    META_ADS = "Meta Ads"
    GOOGLE_ADS = "Google Ads"
    WHATSAPP = "WhatsApp"
    SITE = "Site"
    INDICACAO = "Indicação"
    OUTROS = "Outros"


class Lead(Base):
    """Modelo de dados para leads"""
    __tablename__ = "leads"

    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String(255), nullable=False, index=True)
    email = Column(String(255), nullable=False, index=True)
    telefone = Column(String(20), nullable=False)
    origem = Column(Enum(LeadOrigin), nullable=False, index=True)
    interesse = Column(Text, nullable=True)
    renda_aproximada = Column(Float, nullable=True)
    cidade = Column(String(100), nullable=True, index=True)
    
    # Campos de scoring
    score = Column(Integer, default=0, index=True)
    status = Column(Enum(LeadStatus), default=LeadStatus.PROCESSANDO, index=True)
    
    # Campos de controle
    processado = Column(String(1), default="N")  # Y/N
    observacoes = Column(Text, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    follow_up_date = Column(DateTime(timezone=True), nullable=True)
    
    def __repr__(self):
        return f"<Lead(id={self.id}, nome='{self.nome}', status='{self.status}')>"
    
    def to_dict(self):
        """Converte o modelo para dicionário"""
        return {
            "id": self.id,
            "nome": self.nome,
            "email": self.email,
            "telefone": self.telefone,
            "origem": self.origem.value if self.origem else None,
            "interesse": self.interesse,
            "renda_aproximada": self.renda_aproximada,
            "cidade": self.cidade,
            "score": self.score,
            "status": self.status.value if self.status else None,
            "processado": self.processado,
            "observacoes": self.observacoes,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "follow_up_date": self.follow_up_date.isoformat() if self.follow_up_date else None
        }