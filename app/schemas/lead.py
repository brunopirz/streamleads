from pydantic import BaseModel, EmailStr, validator
from typing import Optional
from datetime import datetime
from app.models.lead import LeadStatus, LeadOrigin


class LeadBase(BaseModel):
    """Schema base para leads"""
    nome: str
    email: EmailStr
    telefone: str
    origem: LeadOrigin
    interesse: Optional[str] = None
    renda_aproximada: Optional[float] = None
    cidade: Optional[str] = None
    observacoes: Optional[str] = None

    @validator('telefone')
    def validate_telefone(cls, v):
        # Remove caracteres não numéricos
        telefone_limpo = ''.join(filter(str.isdigit, v))
        if len(telefone_limpo) < 10 or len(telefone_limpo) > 11:
            raise ValueError('Telefone deve ter entre 10 e 11 dígitos')
        return telefone_limpo

    @validator('nome')
    def validate_nome(cls, v):
        if len(v.strip()) < 2:
            raise ValueError('Nome deve ter pelo menos 2 caracteres')
        return v.strip().title()

    @validator('renda_aproximada')
    def validate_renda(cls, v):
        if v is not None and v < 0:
            raise ValueError('Renda não pode ser negativa')
        return v


class LeadCreate(LeadBase):
    """Schema para criação de leads"""
    pass


class LeadUpdate(BaseModel):
    """Schema para atualização de leads"""
    nome: Optional[str] = None
    email: Optional[EmailStr] = None
    telefone: Optional[str] = None
    origem: Optional[LeadOrigin] = None
    interesse: Optional[str] = None
    renda_aproximada: Optional[float] = None
    cidade: Optional[str] = None
    status: Optional[LeadStatus] = None
    observacoes: Optional[str] = None
    follow_up_date: Optional[datetime] = None

    @validator('telefone')
    def validate_telefone(cls, v):
        if v is not None:
            telefone_limpo = ''.join(filter(str.isdigit, v))
            if len(telefone_limpo) < 10 or len(telefone_limpo) > 11:
                raise ValueError('Telefone deve ter entre 10 e 11 dígitos')
            return telefone_limpo
        return v

    @validator('nome')
    def validate_nome(cls, v):
        if v is not None:
            if len(v.strip()) < 2:
                raise ValueError('Nome deve ter pelo menos 2 caracteres')
            return v.strip().title()
        return v


class LeadResponse(LeadBase):
    """Schema para resposta de leads"""
    id: int
    score: int
    status: LeadStatus
    processado: str
    created_at: datetime
    updated_at: Optional[datetime] = None
    follow_up_date: Optional[datetime] = None

    class Config:
        from_attributes = True


class LeadListResponse(BaseModel):
    """Schema para lista de leads com paginação"""
    leads: list[LeadResponse]
    total: int
    page: int
    per_page: int
    total_pages: int


class LeadStats(BaseModel):
    """Schema para estatísticas de leads"""
    total_leads: int
    leads_quentes: int
    leads_mornos: int
    leads_frios: int
    leads_processando: int
    media_score: float
    leads_hoje: int