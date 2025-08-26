# Ro-dou Coolify Deployment - Quick Reference

## 📁 Arquivos Criados para Coolify

1. **`.dockerignore`** - Otimiza builds Docker excluindo arquivos desnecessários
2. **`.env.example`** - Template de variáveis de ambiente
3. **`docker-compose.coolify.yml`** - Configuração Docker Compose para Coolify
4. **`setup-coolify.sh`** - Script de inicialização automática
5. **`health-check.sh`** - Script de verificação de saúde dos serviços
6. **`COOLIFY-DEPLOYMENT.md`** - Documentação completa de deploy
7. **`Dockerfile` (otimizado)** - Dockerfile melhorado para produção

## 🚀 Deploy Rápido no Coolify

### 1. Configurar no Coolify:
- Tipo: Docker Compose
- Arquivo: `docker-compose.coolify.yml`
- Branch: `main`

### 2. Variáveis Essenciais:
```env
POSTGRES_PASSWORD=sua-senha-segura
AIRFLOW__CORE__FERNET_KEY=sua-chave-fernet
AIRFLOW__WEBSERVER__SECRET_KEY=sua-chave-web
_AIRFLOW_WWW_USER_PASSWORD=sua-senha-admin
INLABS_PORTAL_LOGIN=usuario@inlabs.gov.br
INLABS_PORTAL_PASSWORD=senha-inlabs
```

### 3. Após Deploy:
```bash
# Execute dentro do container webserver
./setup-coolify.sh
```

### 4. Acessos:
- **Airflow**: `https://seu-dominio.com`
- **SMTP4Dev**: `https://smtp.seu-dominio.com` (opcional)

## 🔍 Health Check:
```bash
# Verificação completa
./health-check.sh full

# Verificação rápida
./health-check.sh quick
```

## 📖 Documentação Completa:
Veja `COOLIFY-DEPLOYMENT.md` para instruções detalhadas.

---
**Pronto para deploy! 🎉**