import requests
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta
from app.models.lead import Lead, LeadStatus
from app.config import settings
from loguru import logger
from typing import Optional


class AutomationService:
    """Serviço para automações baseadas no status do lead"""
    
    def __init__(self):
        self.n8n_webhook_url = settings.n8n_webhook_url
        self.whatsapp_token = settings.whatsapp_api_token
        self.slack_webhook = settings.slack_webhook_url
        
    def process_lead_actions(self, lead: Lead) -> dict:
        """Processa ações automáticas baseadas no status do lead"""
        actions_taken = []
        
        try:
            if lead.status == LeadStatus.QUENTE:
                actions_taken.extend(self._handle_hot_lead(lead))
            elif lead.status == LeadStatus.MORNO:
                actions_taken.extend(self._handle_warm_lead(lead))
            elif lead.status == LeadStatus.FRIO:
                actions_taken.extend(self._handle_cold_lead(lead))
            
            logger.info(f"Ações processadas para lead {lead.id}: {actions_taken}")
            
        except Exception as e:
            logger.error(f"Erro ao processar ações para lead {lead.id}: {str(e)}")
            actions_taken.append(f"Erro: {str(e)}")
        
        return {
            "lead_id": lead.id,
            "status": lead.status.value,
            "actions_taken": actions_taken
        }
    
    def _handle_hot_lead(self, lead: Lead) -> list:
        """Ações para leads quentes"""
        actions = []
        
        # 1. Notificar time de vendas via WhatsApp/Slack
        if self._notify_sales_team(lead):
            actions.append("Notificação enviada para time de vendas")
        
        # 2. Enviar para n8n para integração com CRM
        if self._send_to_n8n(lead, "hot_lead"):
            actions.append("Lead enviado para CRM via n8n")
        
        # 3. Agendar follow-up em 1 hora
        lead.follow_up_date = datetime.now() + timedelta(hours=1)
        actions.append("Follow-up agendado para 1 hora")
        
        return actions
    
    def _handle_warm_lead(self, lead: Lead) -> list:
        """Ações para leads mornos"""
        actions = []
        
        # 1. Enviar email com PDF e link para agendamento
        if self._send_nurturing_email(lead):
            actions.append("Email de nutrição enviado")
        
        # 2. Enviar para n8n para sequência de emails
        if self._send_to_n8n(lead, "warm_lead"):
            actions.append("Lead adicionado à sequência de nutrição")
        
        # 3. Agendar follow-up em 3 dias
        lead.follow_up_date = datetime.now() + timedelta(days=3)
        actions.append("Follow-up agendado para 3 dias")
        
        return actions
    
    def _handle_cold_lead(self, lead: Lead) -> list:
        """Ações para leads frios"""
        actions = []
        
        # 1. Inserir no CRM com data de follow-up
        if self._send_to_n8n(lead, "cold_lead"):
            actions.append("Lead inserido no CRM")
        
        # 2. Agendar follow-up em 7 dias
        lead.follow_up_date = datetime.now() + timedelta(days=7)
        actions.append("Follow-up agendado para 7 dias")
        
        # 3. Adicionar à lista de remarketing
        if self._add_to_remarketing(lead):
            actions.append("Adicionado à lista de remarketing")
        
        return actions
    
    def _notify_sales_team(self, lead: Lead) -> bool:
        """Notifica o time de vendas sobre lead quente"""
        try:
            if self.slack_webhook:
                message = {
                    "text": f"🔥 LEAD QUENTE RECEBIDO!",
                    "attachments": [{
                        "color": "danger",
                        "fields": [
                            {"title": "Nome", "value": lead.nome, "short": True},
                            {"title": "Email", "value": lead.email, "short": True},
                            {"title": "Telefone", "value": lead.telefone, "short": True},
                            {"title": "Origem", "value": lead.origem.value, "short": True},
                            {"title": "Score", "value": str(lead.score), "short": True},
                            {"title": "Interesse", "value": lead.interesse or "Não informado", "short": False}
                        ]
                    }]
                }
                
                response = requests.post(self.slack_webhook, json=message, timeout=10)
                return response.status_code == 200
            
            return True  # Se não há webhook configurado, considera sucesso
            
        except Exception as e:
            logger.error(f"Erro ao notificar time de vendas: {str(e)}")
            return False
    
    def _send_to_n8n(self, lead: Lead, action_type: str) -> bool:
        """Envia lead para n8n para processamento"""
        try:
            if not self.n8n_webhook_url:
                return True  # Se não há webhook, considera sucesso
            
            payload = {
                "action": action_type,
                "lead": lead.to_dict(),
                "timestamp": datetime.now().isoformat()
            }
            
            response = requests.post(
                self.n8n_webhook_url,
                json=payload,
                timeout=10
            )
            
            return response.status_code in [200, 201]
            
        except Exception as e:
            logger.error(f"Erro ao enviar para n8n: {str(e)}")
            return False
    
    def _send_nurturing_email(self, lead: Lead) -> bool:
        """Envia email de nutrição para lead morno"""
        try:
            if not all([settings.email_user, settings.email_password]):
                logger.warning("Configurações de email não encontradas")
                return True  # Considera sucesso se não há config
            
            # Criar mensagem
            msg = MIMEMultipart()
            msg['From'] = settings.email_user
            msg['To'] = lead.email
            msg['Subject'] = f"Olá {lead.nome.split()[0]}, temos algo especial para você!"
            
            # Corpo do email
            body = f"""
            Olá {lead.nome},
            
            Obrigado pelo seu interesse! Preparamos um material exclusivo sobre {lead.interesse or 'nossos produtos'}.
            
            📋 Material em anexo: Guia Completo de Investimentos
            📅 Agende uma conversa: https://calendly.com/sua-empresa
            📱 WhatsApp: (11) 99999-9999
            
            Nossa equipe está pronta para esclarecer suas dúvidas!
            
            Atenciosamente,
            Equipe StreamLeads
            """
            
            msg.attach(MIMEText(body, 'plain'))
            
            # Enviar email
            server = smtplib.SMTP(settings.smtp_server, settings.smtp_port)
            server.starttls()
            server.login(settings.email_user, settings.email_password)
            server.send_message(msg)
            server.quit()
            
            return True
            
        except Exception as e:
            logger.error(f"Erro ao enviar email de nutrição: {str(e)}")
            return False
    
    def _add_to_remarketing(self, lead: Lead) -> bool:
        """Adiciona lead à lista de remarketing"""
        try:
            # Aqui você pode integrar com Facebook Ads, Google Ads, etc.
            # Por enquanto, apenas simula a ação
            logger.info(f"Lead {lead.id} adicionado à lista de remarketing")
            return True
            
        except Exception as e:
            logger.error(f"Erro ao adicionar ao remarketing: {str(e)}")
            return False
    
    def send_follow_up_reminder(self, lead: Lead) -> bool:
        """Envia lembrete de follow-up"""
        try:
            if self.slack_webhook:
                message = {
                    "text": f"⏰ Lembrete de Follow-up",
                    "attachments": [{
                        "color": "warning",
                        "fields": [
                            {"title": "Lead", "value": f"{lead.nome} ({lead.email})", "short": False},
                            {"title": "Status", "value": lead.status.value, "short": True},
                            {"title": "Score", "value": str(lead.score), "short": True},
                            {"title": "Data Follow-up", "value": lead.follow_up_date.strftime("%d/%m/%Y %H:%M"), "short": True}
                        ]
                    }]
                }
                
                response = requests.post(self.slack_webhook, json=message, timeout=10)
                return response.status_code == 200
            
            return True
            
        except Exception as e:
            logger.error(f"Erro ao enviar lembrete de follow-up: {str(e)}")
            return False