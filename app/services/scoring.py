from app.models.lead import Lead, LeadStatus
from app.config import settings
from loguru import logger
from typing import List


class LeadScoringService:
    """Serviço para calcular score e classificar leads"""
    
    def __init__(self):
        self.score_required_fields = settings.score_required_fields
        self.score_high_ticket = settings.score_high_ticket
        self.score_region = settings.score_region
        self.hot_threshold = settings.hot_lead_threshold
        self.warm_threshold = settings.warm_lead_threshold
        
        # Palavras-chave para produtos de alto ticket
        self.high_ticket_keywords = [
            "imóvel", "apartamento", "casa", "terreno", "lote",
            "investimento", "premium", "luxo", "cobertura",
            "comercial", "empresarial", "corporativo"
        ]
        
        # Cidades/regiões atendidas (exemplo)
        self.served_regions = [
            "são paulo", "sp", "rio de janeiro", "rj", "belo horizonte",
            "brasília", "salvador", "fortaleza", "recife", "porto alegre",
            "curitiba", "goiânia", "campinas", "santos", "osasco"
        ]
    
    def calculate_score(self, lead: Lead) -> int:
        """Calcula o score do lead baseado nas regras de negócio"""
        score = 0
        
        # Regra 1: Campos obrigatórios preenchidos
        if self._has_required_fields(lead):
            score += self.score_required_fields
            logger.info(f"Lead {lead.id}: +{self.score_required_fields} pontos por campos obrigatórios")
        
        # Regra 2: Interesse em produto de alto ticket
        if self._has_high_ticket_interest(lead):
            score += self.score_high_ticket
            logger.info(f"Lead {lead.id}: +{self.score_high_ticket} pontos por interesse em alto ticket")
        
        # Regra 3: Região atendida
        if self._is_in_served_region(lead):
            score += self.score_region
            logger.info(f"Lead {lead.id}: +{self.score_region} pontos por região atendida")
        
        # Regra 4: Renda aproximada (bônus)
        renda_bonus = self._calculate_income_bonus(lead)
        if renda_bonus > 0:
            score += renda_bonus
            logger.info(f"Lead {lead.id}: +{renda_bonus} pontos por renda")
        
        logger.info(f"Lead {lead.id}: Score total calculado: {score}")
        return score
    
    def classify_lead(self, score: int) -> LeadStatus:
        """Classifica o lead baseado no score"""
        if score >= self.hot_threshold:
            return LeadStatus.QUENTE
        elif score >= self.warm_threshold:
            return LeadStatus.MORNO
        else:
            return LeadStatus.FRIO
    
    def process_lead(self, lead: Lead) -> Lead:
        """Processa um lead: calcula score e classifica"""
        lead.score = self.calculate_score(lead)
        lead.status = self.classify_lead(lead.score)
        lead.processado = "Y"
        
        logger.info(
            f"Lead processado - ID: {lead.id}, Nome: {lead.nome}, "
            f"Score: {lead.score}, Status: {lead.status.value}"
        )
        
        return lead
    
    def _has_required_fields(self, lead: Lead) -> bool:
        """Verifica se todos os campos obrigatórios estão preenchidos"""
        required_fields = [lead.nome, lead.email, lead.telefone, lead.origem]
        return all(field is not None and str(field).strip() != "" for field in required_fields)
    
    def _has_high_ticket_interest(self, lead: Lead) -> bool:
        """Verifica se o lead tem interesse em produtos de alto ticket"""
        if not lead.interesse:
            return False
        
        interesse_lower = lead.interesse.lower()
        return any(keyword in interesse_lower for keyword in self.high_ticket_keywords)
    
    def _is_in_served_region(self, lead: Lead) -> bool:
        """Verifica se o lead está em uma região atendida"""
        if not lead.cidade:
            return False
        
        cidade_lower = lead.cidade.lower()
        return any(region in cidade_lower for region in self.served_regions)
    
    def _calculate_income_bonus(self, lead: Lead) -> int:
        """Calcula bônus baseado na renda aproximada"""
        if not lead.renda_aproximada:
            return 0
        
        # Bônus progressivo baseado na renda
        if lead.renda_aproximada >= 20000:
            return 10  # Renda muito alta
        elif lead.renda_aproximada >= 10000:
            return 7   # Renda alta
        elif lead.renda_aproximada >= 5000:
            return 5   # Renda média-alta
        elif lead.renda_aproximada >= 3000:
            return 3   # Renda média
        else:
            return 0   # Sem bônus
    
    def get_scoring_explanation(self, lead: Lead) -> dict:
        """Retorna explicação detalhada do scoring"""
        explanation = {
            "score_total": lead.score,
            "status": lead.status.value,
            "detalhes": []
        }
        
        if self._has_required_fields(lead):
            explanation["detalhes"].append({
                "regra": "Campos obrigatórios preenchidos",
                "pontos": self.score_required_fields
            })
        
        if self._has_high_ticket_interest(lead):
            explanation["detalhes"].append({
                "regra": "Interesse em produto de alto ticket",
                "pontos": self.score_high_ticket
            })
        
        if self._is_in_served_region(lead):
            explanation["detalhes"].append({
                "regra": "Região atendida pela empresa",
                "pontos": self.score_region
            })
        
        renda_bonus = self._calculate_income_bonus(lead)
        if renda_bonus > 0:
            explanation["detalhes"].append({
                "regra": f"Bônus por renda (R$ {lead.renda_aproximada:,.2f})",
                "pontos": renda_bonus
            })
        
        return explanation