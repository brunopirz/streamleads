from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # Database
    database_url: str = "postgresql://postgres:postgres123@localhost:5432/streamleads"
    
    # Application
    environment: str = "development"
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    debug: bool = True
    
    # Security
    secret_key: str = "your-secret-key-change-in-production"
    access_token_expire_minutes: int = 30
    
    # External Integrations
    n8n_webhook_url: Optional[str] = None
    whatsapp_api_token: Optional[str] = None
    slack_webhook_url: Optional[str] = None
    
    # Email Configuration
    smtp_server: str = "smtp.gmail.com"
    smtp_port: int = 587
    email_user: Optional[str] = None
    email_password: Optional[str] = None
    
    # Scoring Configuration
    score_required_fields: int = 10
    score_high_ticket: int = 15
    score_region: int = 5
    hot_lead_threshold: int = 25
    warm_lead_threshold: int = 15
    
    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()