#!/usr/bin/env python3
"""
Script para inicializar o banco de dados e popular com dados de exemplo.
"""

import sys
import os
from datetime import datetime, timedelta
import random

# Adicionar o diretório raiz ao path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import engine, SessionLocal, create_tables
from app.models.lead import Lead, LeadStatus, LeadOrigin
from app.services.scoring import LeadScoringService
from app.services.automation import AutomationService
from loguru import logger


def create_sample_leads():
    """Cria leads de exemplo para testes"""
    
    sample_leads = [
        {
            "nome": "João Silva",
            "email": "joao.silva@email.com",
            "telefone": "11999999999",
            "origem": LeadOrigin.META_ADS,
            "interesse": "Apartamento na Zona Sul de São Paulo",
            "renda_aproximada": 8000.0,
            "cidade": "São Paulo"
        },
        {
            "nome": "Maria Santos",
            "email": "maria.santos@email.com",
            "telefone": "11888888888",
            "origem": LeadOrigin.GOOGLE_ADS,
            "interesse": "Casa para investimento",
            "renda_aproximada": 15000.0,
            "cidade": "Rio de Janeiro"
        },
        {
            "nome": "Pedro Oliveira",
            "email": "pedro.oliveira@email.com",
            "telefone": "11777777777",
            "origem": LeadOrigin.SITE,
            "interesse": "Informações sobre financiamento",
            "renda_aproximada": 4000.0,
            "cidade": "Campinas"
        },
        {
            "nome": "Ana Costa",
            "email": "ana.costa@email.com",
            "telefone": "11666666666",
            "origem": LeadOrigin.WHATSAPP,
            "interesse": "Cobertura de luxo",
            "renda_aproximada": 25000.0,
            "cidade": "São Paulo"
        },
        {
            "nome": "Carlos Ferreira",
            "email": "carlos.ferreira@email.com",
            "telefone": "11555555555",
            "origem": LeadOrigin.INDICACAO,
            "interesse": "Terreno para construção",
            "renda_aproximada": 12000.0,
            "cidade": "Belo Horizonte"
        },
        {
            "nome": "Lucia Mendes",
            "email": "lucia.mendes@email.com",
            "telefone": "11444444444",
            "origem": LeadOrigin.META_ADS,
            "interesse": "Apartamento pequeno",
            "renda_aproximada": 3500.0,
            "cidade": "Santos"
        },
        {
            "nome": "Roberto Lima",
            "email": "roberto.lima@email.com",
            "telefone": "11333333333",
            "origem": LeadOrigin.GOOGLE_ADS,
            "interesse": "Imóvel comercial",
            "renda_aproximada": 18000.0,
            "cidade": "São Paulo"
        },
        {
            "nome": "Fernanda Rocha",
            "email": "fernanda.rocha@email.com",
            "telefone": "11222222222",
            "origem": LeadOrigin.SITE,
            "interesse": "Consultoria de investimentos",
            "renda_aproximada": 6000.0,
            "cidade": "Curitiba"
        },
        {
            "nome": "Marcos Alves",
            "email": "marcos.alves@email.com",
            "telefone": "11111111111",
            "origem": LeadOrigin.OUTROS,
            "interesse": "Informações gerais",
            "renda_aproximada": 2500.0,
            "cidade": "Fortaleza"
        },
        {
            "nome": "Patricia Gomes",
            "email": "patricia.gomes@email.com",
            "telefone": "11000000000",
            "origem": LeadOrigin.META_ADS,
            "interesse": "Apartamento de alto padrão",
            "renda_aproximada": 22000.0,
            "cidade": "São Paulo"
        }
    ]
    
    return sample_leads


def init_database():
    """Inicializa o banco de dados"""
    logger.info("Iniciando criação das tabelas...")
    
    try:
        # Criar tabelas
        create_tables()
        logger.info("✅ Tabelas criadas com sucesso!")
        
        # Verificar se já existem dados
        db = SessionLocal()
        existing_leads = db.query(Lead).count()
        
        if existing_leads > 0:
            logger.info(f"Banco já possui {existing_leads} leads. Pulando inserção de dados de exemplo.")
            db.close()
            return
        
        logger.info("Criando leads de exemplo...")
        
        # Criar serviços
        scoring_service = LeadScoringService()
        automation_service = AutomationService()
        
        # Criar leads de exemplo
        sample_leads = create_sample_leads()
        
        for i, lead_data in enumerate(sample_leads):
            # Criar lead
            lead = Lead(**lead_data)
            
            # Variar as datas de criação (últimos 30 dias)
            days_ago = random.randint(0, 30)
            hours_ago = random.randint(0, 23)
            lead.created_at = datetime.now() - timedelta(days=days_ago, hours=hours_ago)
            
            # Processar scoring
            lead = scoring_service.process_lead(lead)
            
            # Adicionar ao banco
            db.add(lead)
            
            logger.info(
                f"Lead criado: {lead.nome} - Status: {lead.status.value} - Score: {lead.score}"
            )
        
        # Commit das alterações
        db.commit()
        
        # Buscar leads criados para executar automações
        created_leads = db.query(Lead).all()
        
        logger.info("Executando automações para leads de exemplo...")
        
        for lead in created_leads:
            try:
                automation_result = automation_service.process_lead_actions(lead)
                logger.info(f"Automações executadas para {lead.nome}: {automation_result['actions_taken']}")
            except Exception as e:
                logger.warning(f"Erro ao executar automações para {lead.nome}: {str(e)}")
        
        db.commit()
        db.close()
        
        logger.info(f"✅ {len(sample_leads)} leads de exemplo criados com sucesso!")
        
    except Exception as e:
        logger.error(f"❌ Erro ao inicializar banco de dados: {str(e)}")
        raise


def show_stats():
    """Mostra estatísticas do banco"""
    try:
        db = SessionLocal()
        
        total_leads = db.query(Lead).count()
        leads_quentes = db.query(Lead).filter(Lead.status == LeadStatus.QUENTE).count()
        leads_mornos = db.query(Lead).filter(Lead.status == LeadStatus.MORNO).count()
        leads_frios = db.query(Lead).filter(Lead.status == LeadStatus.FRIO).count()
        
        logger.info("📊 Estatísticas do Banco de Dados:")
        logger.info(f"   Total de leads: {total_leads}")
        logger.info(f"   Leads quentes: {leads_quentes}")
        logger.info(f"   Leads mornos: {leads_mornos}")
        logger.info(f"   Leads frios: {leads_frios}")
        
        # Leads por origem
        logger.info("\n📈 Leads por origem:")
        for origem in LeadOrigin:
            count = db.query(Lead).filter(Lead.origem == origem).count()
            logger.info(f"   {origem.value}: {count}")
        
        db.close()
        
    except Exception as e:
        logger.error(f"Erro ao buscar estatísticas: {str(e)}")


def main():
    """Função principal"""
    logger.info("🚀 Inicializando StreamLeads Database...")
    
    try:
        # Inicializar banco
        init_database()
        
        # Mostrar estatísticas
        show_stats()
        
        logger.info("\n✅ Inicialização concluída com sucesso!")
        logger.info("\n🔗 Próximos passos:")
        logger.info("   1. Inicie a API: python -m app.main")
        logger.info("   2. Acesse a documentação: http://localhost:8000/docs")
        logger.info("   3. Inicie o dashboard: streamlit run dashboard/main.py")
        
    except Exception as e:
        logger.error(f"❌ Falha na inicialização: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()