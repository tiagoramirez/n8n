#!/bin/bash
set -e

# docker-entrypoint.sh - Script de inicio para nginx + certbot

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Variables
DOMAIN=${DOMAIN:-"tiagoramirez.lat"}
SUBDOMAIN=${SUBDOMAIN:-"n8n"}
FULL_DOMAIN="$SUBDOMAIN.$DOMAIN"
EMAIL=${EMAIL:-"tiagoramirez.dev@pm.me"}
CERT_PATH="/etc/nginx/ssl"
LETSENCRYPT_PATH="/etc/letsencrypt"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🚀 Nginx + Certbot Initialization${NC}"
echo -e "${BLUE}========================================${NC}"

# Function to generate certificates
generate_certs() {
    echo -e "${BLUE}[1/4] Generating certificates...${NC}"
    
    # Create webroot directory for validation
    mkdir -p /var/www/certbot
    
    # Generate certificate
    certbot certonly \
        --webroot \
        -w /var/www/certbot \
        -d $DOMAIN \
        -d $FULL_DOMAIN \
        --email $EMAIL \
        --agree-tos \
        --non-interactive \
        --force-renewal \
        2>/dev/null || true
    
    # Copy certificates to nginx location
    if [ -f "$LETSENCRYPT_PATH/live/$FULL_DOMAIN/fullchain.pem" ]; then
        cp $LETSENCRYPT_PATH/live/$FULL_DOMAIN/fullchain.pem $CERT_PATH/cert.pem
        cp $LETSENCRYPT_PATH/live/$FULL_DOMAIN/privkey.pem $CERT_PATH/key.pem
        chmod 600 $CERT_PATH/key.pem
        chmod 644 $CERT_PATH/cert.pem
        echo -e "${GREEN}✅ Certificates generated successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Error generating certificates${NC}"
        return 1
    fi
}

# Function to generate self-signed certificate (fallback)
generate_self_signed() {
    echo -e "${BLUE}[2/4] Generating self-signed certificate (fallback)...${NC}"
    
    openssl req -x509 -newkey rsa:4096 \
        -keyout $CERT_PATH/key.pem \
        -out $CERT_PATH/cert.pem \
        -days 365 -nodes \
        -subj "/CN=$FULL_DOMAIN"
    
    chmod 600 $CERT_PATH/key.pem
    chmod 644 $CERT_PATH/cert.pem
    
    echo -e "${GREEN}✅ Self-signed certificate generated${NC}"
}

# Function to configure renewal cron
setup_renewal_cron() {
    echo -e "${BLUE}[3/4] Configuring automatic renewal...${NC}"
    
    # Create crontab for automatic renewal
    echo "0 3 * * * /usr/local/bin/renew-certs.sh" | crontab -
    
    # Start dcron (cron daemon)
    crond -f -l 2 &
    CROND_PID=$!
    
    echo -e "${GREEN}✅ Automatic renewal configured${NC}"
}

# Function to validate nginx configuration
validate_nginx() {
    echo -e "${BLUE}[4/4] Validating nginx configuration...${NC}"
    
    nginx -t > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Nginx configuration validated${NC}"
        return 0
    else
        echo -e "${RED}❌ Error validating nginx configuration${NC}"
        return 1
    fi
}

# Main execution
echo -e "${BLUE}Initializing with parameters:${NC}"
echo "  Domain: $DOMAIN"
echo "  Subdomain: $FULL_DOMAIN"
echo "  Email: $EMAIL"
echo ""

# Try to generate Let's Encrypt certificates
if generate_certs; then
    echo -e "${GREEN}✅ Using Let's Encrypt certificates${NC}"
else
    echo -e "${YELLOW}⚠️ Let's Encrypt failed, using self-signed certificate${NC}"
    generate_self_signed
fi

#   Configure automatic renewal
setup_renewal_cron

# Validate nginx
validate_nginx

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Initialization completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Execute main command (nginx)
exec "$@"