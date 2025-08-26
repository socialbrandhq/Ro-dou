# Ro-dou Coolify Deployment Guide

Este guia fornece instruções completas para fazer o deploy do Ro-dou no Coolify, uma plataforma de hospedagem self-hosted similar ao Heroku.

## 📋 Pré-requisitos

- Servidor Coolify configurado e funcionando
- Acesso ao painel de administração do Coolify
- Repositório Git do Ro-dou (este repositório)
- Credenciais do portal INLABS (para integração com dados governamentais)

## 🚀 Deployment no Coolify

### Passo 1: Configurar o Projeto no Coolify

1. **Acessar o Painel do Coolify**
   - Faça login no seu painel Coolify
   - Navegue até "Projects" → "New Project"

2. **Criar Nova Aplicação**
   - Clique em "New Resource" → "Docker Compose"
   - Escolha "Git Repository" como fonte
   - Insira a URL do repositório: `https://github.com/seu-usuario/Ro-dou.git`

3. **Configurar Build Settings**
   - **Docker Compose File**: `docker-compose.coolify.yml`
   - **Branch**: `main` (ou a branch desejada)
   - **Build Pack**: Docker Compose

### Passo 2: Configurar Variáveis de Ambiente

No painel do Coolify, vá para "Environment Variables" e adicione as seguintes variáveis:

#### Configurações Essenciais

```env
# Configuração do Banco de Dados
POSTGRES_USER=airflow
POSTGRES_PASSWORD=sua-senha-postgres-segura
POSTGRES_DB=airflow

# Configuração do Airflow
AIRFLOW__CORE__FERNET_KEY=gere-uma-chave-fernet-segura
AIRFLOW__WEBSERVER__SECRET_KEY=sua-chave-secreta-web
AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:sua-senha-postgres-segura@postgres:5432/airflow

# Credenciais de Admin do Airflow
_AIRFLOW_WWW_USER_USERNAME=admin
_AIRFLOW_WWW_USER_PASSWORD=sua-senha-admin-segura

# Configuração SMTP (opcional)
AIRFLOW__SMTP__SMTP_HOST=seu-servidor-smtp
AIRFLOW__SMTP__SMTP_MAIL_FROM=airflow@seudominio.com
AIRFLOW__SMTP__SMTP_USER=seu-usuario-smtp
AIRFLOW__SMTP__SMTP_PASSWORD=sua-senha-smtp

# Credenciais INLABS (IMPORTANTE)
INLABS_PORTAL_LOGIN=seu-usuario@inlabs.gov.br
INLABS_PORTAL_PASSWORD=sua-senha-inlabs

# Configuração de Domínio
APP_DOMAIN=seu-dominio.com
```

#### Como Gerar Chave Fernet Segura

Execute o seguinte comando para gerar uma chave Fernet:

```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

### Passo 3: Configurar Domínios e Portas

1. **Configurar Domínio Principal**
   - No Coolify, vá para "Domains"
   - Adicione seu domínio principal (ex: `ro-dou.seudominio.com`)
   - Configure para apontar para o serviço `airflow-webserver` na porta `8080`

2. **Configurar Domínio SMTP (Opcional)**
   - Adicione subdomínio para SMTP4Dev (ex: `smtp.ro-dou.seudominio.com`)
   - Configure para apontar para o serviço `smtp4dev` na porta `80`

### Passo 4: Deploy da Aplicação

1. **Iniciar o Deploy**
   - Clique em "Deploy" no painel do Coolify
   - Aguarde o build e deploy dos containers

2. **Monitorar o Deploy**
   - Acompanhe os logs no painel
   - Verifique se todos os serviços estão rodando corretamente

### Passo 5: Inicialização Automática

Após o deploy bem-sucedido, execute o script de inicialização:

1. **Via Coolify Terminal**
   - Acesse o terminal do container `airflow-webserver`
   - Execute: `./setup-coolify.sh`

2. **Verificar Inicialização**
   - O script criará automaticamente:
     - Variáveis do Airflow
     - Conexões de banco de dados
     - Banco INLABS
     - Ativação de DAGs

## 🔧 Configuração Pós-Deploy

### Acessar a Interface Web

- **Airflow UI**: `https://ro-dou.seudominio.com`
  - Usuário: valor de `_AIRFLOW_WWW_USER_USERNAME`
  - Senha: valor de `_AIRFLOW_WWW_USER_PASSWORD`

- **SMTP4Dev**: `https://smtp.ro-dou.seudominio.com` (se configurado)

### Configurar DAGs Personalizados

1. **Adicionar Configurações YAML**
   - As configurações ficam em `/opt/airflow/dags/ro_dou/dag_confs/`
   - Use os exemplos em `dag_confs/examples_and_tests/` como base

2. **Configurar Notificações**
   - Configure Slack: adicione webhook URL nas configurações
   - Configure Discord: adicione webhook URL nas configurações
   - Configure Email: atualize configurações SMTP

### Atualizar Credenciais INLABS

1. **Acessar Airflow Admin → Connections**
2. **Editar conexão "inlabs_portal"**
3. **Atualizar com credenciais reais do portal INLABS**

## 📊 Monitoramento e Logs

### Visualizar Logs

No Coolify:
- Vá para "Logs" no painel da aplicação
- Selecione o serviço desejado (webserver, scheduler, etc.)

### Health Checks

A aplicação inclui health checks automáticos:
- **Airflow Webserver**: `http://localhost:8080/health`
- **PostgreSQL**: comando `pg_isready`
- **Scheduler**: verificação de processo Python

## 🔒 Segurança

### Recomendações de Segurança

1. **Altere senhas padrão**
   - Nunca use as senhas de exemplo em produção
   - Use senhas fortes e únicas

2. **Configure HTTPS**
   - O Coolify automaticamente configura SSL/TLS
   - Verifique se o certificado está válido

3. **Restrinja acesso**
   - Configure firewalls apropriados
   - Use VPN se necessário para acesso interno

4. **Backup regular**
   - Configure backup automático do banco PostgreSQL
   - Faça backup das configurações YAML

## 🛠️ Troubleshooting

### Problemas Comuns

1. **Serviços não iniciam**
   ```bash
   # Verificar logs
   docker logs ro-dou-airflow-webserver-1
   
   # Reiniciar serviços
   docker compose -f docker-compose.coolify.yml restart
   ```

2. **Banco de dados não conecta**
   - Verifique variáveis de ambiente do PostgreSQL
   - Confirme que o serviço postgres está rodando

3. **DAGs não aparecem**
   - Verifique se os arquivos estão no diretório correto
   - Reinicie o scheduler: `docker restart ro-dou-airflow-scheduler-1`

4. **Erro de permissões**
   ```bash
   # Corrigir permissões de arquivos
   docker exec -it ro-dou-airflow-webserver-1 chown -R airflow:root /opt/airflow
   ```

### Comandos Úteis

```bash
# Verificar status dos containers
docker ps

# Acessar logs específicos
docker logs -f ro-dou-airflow-webserver-1

# Executar comandos no Airflow
docker exec -it ro-dou-airflow-webserver-1 airflow dags list

# Reiniciar um serviço específico
docker restart ro-dou-airflow-scheduler-1

# Executar setup manual
docker exec -it ro-dou-airflow-webserver-1 ./setup-coolify.sh
```

## 📝 Configurações Adicionais

### Configurar Notificações Slack

1. **Criar Webhook no Slack**
2. **Adicionar na configuração YAML**:
   ```yaml
   notification:
     slack:
       webhook_url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
       channel: "#ro-dou-alerts"
   ```

### Configurar Notificações Discord

1. **Criar Webhook no Discord**
2. **Adicionar na configuração YAML**:
   ```yaml
   notification:
     discord:
       webhook_url: "https://discord.com/api/webhooks/YOUR/WEBHOOK/URL"
   ```

## 🔄 Atualizações e Manutenção

### Atualizar a Aplicação

1. **Via Git**
   - Faça push das alterações para o repositório
   - O Coolify detectará automaticamente e oferecerá para fazer redeploy

2. **Rollback**
   - Use o painel do Coolify para voltar a uma versão anterior se necessário

### Backup e Restauração

```bash
# Backup do banco PostgreSQL
docker exec ro-dou-postgres-1 pg_dump -U airflow airflow > backup.sql

# Restaurar backup
docker exec -i ro-dou-postgres-1 psql -U airflow airflow < backup.sql
```

## 📞 Suporte

Para problemas específicos do Ro-dou:
- Consulte a documentação em `README.md`
- Verifique issues no repositório GitHub
- Consulte logs detalhados no Airflow UI

Para problemas com Coolify:
- Consulte a documentação oficial do Coolify
- Verifique o status dos serviços no painel

---

**Sucesso no seu deploy! 🎉**

Lembre-se de configurar as credenciais do INLABS e personalizar as configurações YAML conforme suas necessidades específicas de monitoramento.