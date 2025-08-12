import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, date, timedelta
import requests
from typing import Dict, List
import json

# Configuração da página
st.set_page_config(
    page_title="StreamLeads Dashboard",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded"
)

# URL da API
API_BASE_URL = "http://localhost:8000/api/v1"


class StreamLeadsAPI:
    """Cliente para comunicação com a API"""
    
    def __init__(self, base_url: str):
        self.base_url = base_url
    
    def get_leads(self, **params) -> Dict:
        """Busca leads com filtros"""
        try:
            response = requests.get(f"{self.base_url}/leads", params=params)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            st.error(f"Erro ao buscar leads: {str(e)}")
            return {"leads": [], "total": 0}
    
    def get_lead(self, lead_id: int) -> Dict:
        """Busca um lead específico"""
        try:
            response = requests.get(f"{self.base_url}/leads/{lead_id}")
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            st.error(f"Erro ao buscar lead: {str(e)}")
            return {}
    
    def get_stats(self) -> Dict:
        """Busca estatísticas gerais"""
        try:
            response = requests.get(f"{self.base_url}/leads/stats/overview")
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            st.error(f"Erro ao buscar estatísticas: {str(e)}")
            return {}
    
    def get_leads_by_origem(self) -> Dict:
        """Busca leads por origem"""
        try:
            response = requests.get(f"{self.base_url}/leads/stats/origem")
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            st.error(f"Erro ao buscar leads por origem: {str(e)}")
            return {"leads_por_origem": {}}
    
    def get_leads_by_period(self, days: int = 30) -> Dict:
        """Busca leads por período"""
        try:
            response = requests.get(f"{self.base_url}/leads/stats/periodo", params={"days": days})
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            st.error(f"Erro ao buscar leads por período: {str(e)}")
            return {"leads_por_periodo": []}
    
    def update_lead(self, lead_id: int, data: Dict) -> Dict:
        """Atualiza um lead"""
        try:
            response = requests.put(f"{self.base_url}/leads/{lead_id}", json=data)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            st.error(f"Erro ao atualizar lead: {str(e)}")
            return {}
    
    def reprocess_lead(self, lead_id: int) -> Dict:
        """Reprocessa um lead"""
        try:
            response = requests.post(f"{self.base_url}/leads/{lead_id}/reprocess")
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            st.error(f"Erro ao reprocessar lead: {str(e)}")
            return {}


# Inicializar API client
api = StreamLeadsAPI(API_BASE_URL)


def main():
    """Função principal do dashboard"""
    st.title("📊 StreamLeads Dashboard")
    st.markdown("Sistema de Automação de Leads - Painel de Controle")
    
    # Sidebar para navegação
    st.sidebar.title("Navegação")
    page = st.sidebar.selectbox(
        "Escolha uma página",
        ["📈 Overview", "📋 Leads", "🔍 Detalhes do Lead", "⚙️ Configurações"]
    )
    
    if page == "📈 Overview":
        show_overview()
    elif page == "📋 Leads":
        show_leads_list()
    elif page == "🔍 Detalhes do Lead":
        show_lead_details()
    elif page == "⚙️ Configurações":
        show_settings()


def show_overview():
    """Página de overview com estatísticas"""
    st.header("📈 Visão Geral")
    
    # Buscar estatísticas
    stats = api.get_stats()
    
    if stats:
        # Métricas principais
        col1, col2, col3, col4 = st.columns(4)
        
        with col1:
            st.metric(
                label="Total de Leads",
                value=stats.get("total_leads", 0),
                delta=f"+{stats.get('leads_hoje', 0)} hoje"
            )
        
        with col2:
            st.metric(
                label="Leads Quentes",
                value=stats.get("leads_quentes", 0),
                delta=f"{(stats.get('leads_quentes', 0) / max(stats.get('total_leads', 1), 1) * 100):.1f}%"
            )
        
        with col3:
            st.metric(
                label="Leads Mornos",
                value=stats.get("leads_mornos", 0),
                delta=f"{(stats.get('leads_mornos', 0) / max(stats.get('total_leads', 1), 1) * 100):.1f}%"
            )
        
        with col4:
            st.metric(
                label="Score Médio",
                value=f"{stats.get('media_score', 0):.1f}",
                delta="pontos"
            )
        
        st.divider()
        
        # Gráficos
        col1, col2 = st.columns(2)
        
        with col1:
            # Gráfico de pizza - Status dos leads
            status_data = {
                "Quentes": stats.get("leads_quentes", 0),
                "Mornos": stats.get("leads_mornos", 0),
                "Frios": stats.get("leads_frios", 0),
                "Processando": stats.get("leads_processando", 0)
            }
            
            fig_status = px.pie(
                values=list(status_data.values()),
                names=list(status_data.keys()),
                title="Distribuição por Status",
                color_discrete_map={
                    "Quentes": "#ff4444",
                    "Mornos": "#ffaa00",
                    "Frios": "#4444ff",
                    "Processando": "#888888"
                }
            )
            st.plotly_chart(fig_status, use_container_width=True)
        
        with col2:
            # Gráfico de barras - Leads por origem
            origem_data = api.get_leads_by_origem()
            if origem_data.get("leads_por_origem"):
                origens = list(origem_data["leads_por_origem"].keys())
                valores = list(origem_data["leads_por_origem"].values())
                
                fig_origem = px.bar(
                    x=origens,
                    y=valores,
                    title="Leads por Origem",
                    labels={"x": "Origem", "y": "Quantidade"}
                )
                st.plotly_chart(fig_origem, use_container_width=True)
        
        # Gráfico de linha - Leads ao longo do tempo
        st.subheader("📅 Leads ao Longo do Tempo")
        
        period_days = st.selectbox("Período", [7, 15, 30, 60], index=2)
        period_data = api.get_leads_by_period(period_days)
        
        if period_data.get("leads_por_periodo"):
            df_period = pd.DataFrame(period_data["leads_por_periodo"])
            df_period['data'] = pd.to_datetime(df_period['data'])
            
            fig_timeline = px.line(
                df_period,
                x='data',
                y='count',
                title=f"Leads nos Últimos {period_days} Dias",
                labels={"data": "Data", "count": "Quantidade de Leads"}
            )
            st.plotly_chart(fig_timeline, use_container_width=True)


def show_leads_list():
    """Página de listagem de leads"""
    st.header("📋 Lista de Leads")
    
    # Filtros
    st.subheader("🔍 Filtros")
    
    col1, col2, col3 = st.columns(3)
    
    with col1:
        status_filter = st.selectbox(
            "Status",
            ["Todos", "quente", "morno", "frio", "processando"]
        )
    
    with col2:
        origem_filter = st.selectbox(
            "Origem",
            ["Todas", "Meta Ads", "Google Ads", "WhatsApp", "Site", "Indicação", "Outros"]
        )
    
    with col3:
        search_term = st.text_input("Buscar (nome, email, telefone)")
    
    # Filtros de data
    col1, col2 = st.columns(2)
    with col1:
        data_inicio = st.date_input("Data início", value=None)
    with col2:
        data_fim = st.date_input("Data fim", value=None)
    
    # Paginação
    col1, col2 = st.columns(2)
    with col1:
        page = st.number_input("Página", min_value=1, value=1)
    with col2:
        per_page = st.selectbox("Itens por página", [10, 20, 50, 100], index=1)
    
    # Preparar parâmetros
    params = {
        "page": page,
        "per_page": per_page
    }
    
    if status_filter != "Todos":
        params["status"] = status_filter
    
    if origem_filter != "Todas":
        params["origem"] = origem_filter
    
    if search_term:
        params["search"] = search_term
    
    if data_inicio:
        params["data_inicio"] = data_inicio.isoformat()
    
    if data_fim:
        params["data_fim"] = data_fim.isoformat()
    
    # Buscar leads
    leads_data = api.get_leads(**params)
    
    if leads_data.get("leads"):
        st.subheader(f"📊 Resultados ({leads_data.get('total', 0)} leads encontrados)")
        
        # Converter para DataFrame
        df = pd.DataFrame(leads_data["leads"])
        
        # Formatação das colunas
        df['created_at'] = pd.to_datetime(df['created_at']).dt.strftime('%d/%m/%Y %H:%M')
        
        # Exibir tabela
        st.dataframe(
            df[['id', 'nome', 'email', 'telefone', 'origem', 'status', 'score', 'created_at']],
            use_container_width=True,
            column_config={
                "id": "ID",
                "nome": "Nome",
                "email": "Email",
                "telefone": "Telefone",
                "origem": "Origem",
                "status": "Status",
                "score": "Score",
                "created_at": "Criado em"
            }
        )
        
        # Informações de paginação
        total_pages = leads_data.get("total_pages", 1)
        st.info(f"Página {page} de {total_pages} | Total: {leads_data.get('total', 0)} leads")
    
    else:
        st.warning("Nenhum lead encontrado com os filtros aplicados.")


def show_lead_details():
    """Página de detalhes de um lead específico"""
    st.header("🔍 Detalhes do Lead")
    
    lead_id = st.number_input("ID do Lead", min_value=1, value=1)
    
    if st.button("Buscar Lead"):
        lead = api.get_lead(lead_id)
        
        if lead:
            # Informações básicas
            st.subheader("📋 Informações Básicas")
            
            col1, col2 = st.columns(2)
            
            with col1:
                st.write(f"**Nome:** {lead.get('nome')}")
                st.write(f"**Email:** {lead.get('email')}")
                st.write(f"**Telefone:** {lead.get('telefone')}")
                st.write(f"**Cidade:** {lead.get('cidade', 'Não informado')}")
            
            with col2:
                st.write(f"**Origem:** {lead.get('origem')}")
                st.write(f"**Status:** {lead.get('status')}")
                st.write(f"**Score:** {lead.get('score')}")
                st.write(f"**Renda:** R$ {lead.get('renda_aproximada', 0):,.2f}")
            
            # Interesse
            if lead.get('interesse'):
                st.subheader("💭 Interesse")
                st.write(lead['interesse'])
            
            # Observações
            if lead.get('observacoes'):
                st.subheader("📝 Observações")
                st.write(lead['observacoes'])
            
            # Datas
            st.subheader("📅 Datas")
            col1, col2, col3 = st.columns(3)
            
            with col1:
                created_at = pd.to_datetime(lead['created_at']).strftime('%d/%m/%Y %H:%M')
                st.write(f"**Criado em:** {created_at}")
            
            with col2:
                if lead.get('updated_at'):
                    updated_at = pd.to_datetime(lead['updated_at']).strftime('%d/%m/%Y %H:%M')
                    st.write(f"**Atualizado em:** {updated_at}")
            
            with col3:
                if lead.get('follow_up_date'):
                    follow_up = pd.to_datetime(lead['follow_up_date']).strftime('%d/%m/%Y %H:%M')
                    st.write(f"**Follow-up:** {follow_up}")
            
            # Ações
            st.subheader("⚡ Ações")
            
            col1, col2 = st.columns(2)
            
            with col1:
                if st.button("🔄 Reprocessar Lead"):
                    result = api.reprocess_lead(lead_id)
                    if result:
                        st.success("Lead enviado para reprocessamento!")
            
            with col2:
                if st.button("✏️ Editar Lead"):
                    st.session_state.editing_lead = lead_id
                    st.rerun()
            
            # Formulário de edição
            if st.session_state.get('editing_lead') == lead_id:
                st.subheader("✏️ Editar Lead")
                
                with st.form("edit_lead_form"):
                    new_status = st.selectbox(
                        "Status",
                        ["quente", "morno", "frio", "processando"],
                        index=["quente", "morno", "frio", "processando"].index(lead['status'])
                    )
                    
                    new_observacoes = st.text_area(
                        "Observações",
                        value=lead.get('observacoes', '')
                    )
                    
                    submitted = st.form_submit_button("Salvar Alterações")
                    
                    if submitted:
                        update_data = {
                            "status": new_status,
                            "observacoes": new_observacoes
                        }
                        
                        result = api.update_lead(lead_id, update_data)
                        if result:
                            st.success("Lead atualizado com sucesso!")
                            st.session_state.editing_lead = None
                            st.rerun()
        
        else:
            st.error("Lead não encontrado!")


def show_settings():
    """Página de configurações"""
    st.header("⚙️ Configurações")
    
    st.subheader("🔧 Configurações do Sistema")
    
    # Configurações de scoring
    st.write("**Configurações de Scoring:**")
    st.info("""
    - Campos obrigatórios preenchidos: +10 pontos
    - Interesse em produto de alto ticket: +15 pontos
    - Região atendida pela empresa: +5 pontos
    - Bônus por renda: 0-10 pontos baseado na faixa
    """)
    
    # Thresholds
    st.write("**Thresholds de Classificação:**")
    st.info("""
    - Lead Quente: ≥ 25 pontos
    - Lead Morno: 15-24 pontos
    - Lead Frio: < 15 pontos
    """)
    
    # Status da API
    st.subheader("📡 Status da API")
    
    try:
        response = requests.get(f"{API_BASE_URL.replace('/api/v1', '')}/health")
        if response.status_code == 200:
            health_data = response.json()
            st.success(f"✅ API Online - Ambiente: {health_data.get('environment', 'N/A')}")
        else:
            st.error("❌ API com problemas")
    except:
        st.error("❌ API offline ou inacessível")
    
    # Informações do sistema
    st.subheader("ℹ️ Informações do Sistema")
    st.info("""
    **StreamLeads v1.0.0**
    
    Sistema de Automação de Leads desenvolvido com:
    - Backend: FastAPI + PostgreSQL
    - Frontend: Streamlit
    - Automações: n8n integration
    """)


if __name__ == "__main__":
    main()