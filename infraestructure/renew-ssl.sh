#!/bin/bash

# renew-ssl.sh - Renovar certificados SSL manualmente

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

DOMAIN=${1:-"jorge.dev"}
SUBDOMAIN_N8N="n8n.$DOMAIN"
PROJECT_PATH="/home/ubuntu/proyecto"

echo -e "${BLUE}🔄 Renovando certificados...${NC}"

# Renovar con certbot
sudo certbot renew --force-renewal -d $DOMAIN -d $SUBDOMAIN_N8N -d java-app.$DOMAIN

echo -e "${BLUE}📋 Copiando certificados...${NC}"

# Copiar certificados
sudo cp /etc/letsencrypt/live/$SUBDOMAIN_N8N/fullchain.pem $PROJECT_PATH/ssl/cert.pem
sudo cp /etc/letsencrypt/live/$SUBDOMAIN_N8N/privkey.pem $PROJECT_PATH/ssl/key.pem
sudo chown ubuntu:ubuntu $PROJECT_PATH/ssl/*.pem
chmod 600 $PROJECT_PATH/ssl/key.pem
chmod 644 $PROJECT_PATH/ssl/cert.pem

echo -e "${BLUE}🔄 Reiniciando nginx...${NC}"

cd $PROJECT_PATH
docker-compose -f docker-compose.prod.yml restart nginx

echo -e "${GREEN}✅ Certificados renovados y servicios reiniciados${NC}"