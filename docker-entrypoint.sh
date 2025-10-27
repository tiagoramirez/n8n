#!/bin/bash
set -e

# docker-entrypoint.sh - Script de inicio para nginx + certbot

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
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

# Function to generate certificates with --standalone
generate_certs() {
    echo -e "${BLUE}[1/4] Generating certificates with Let's Encrypt...${NC}"
    
    mkdir -p $CERT_PATH
    
    # Use --standalone: Certbot opens its own temporary HTTP server
    # Does not need nginx running
    echo -e "${BLUE}  Attempting Let's Encrypt validation...${NC}"
    
    certbot certonly \
        --standalone \
        --preferred-challenges http \
        -d $DOMAIN \
        -d $FULL_DOMAIN \
        --email $EMAIL \
        --agree-tos \
        --non-interactive \
        --force-renewal \
        2>&1 | tee /tmp/certbot.log
    
    # Verify if it was successful by searching for the success message
    if grep -q "Successfully received certificate" /tmp/certbot.log; then
        # Copy certificates to nginx location
        if [ -f "$LETSENCRYPT_PATH/live/$FULL_DOMAIN/fullchain.pem" ]; then
            cp $LETSENCRYPT_PATH/live/$FULL_DOMAIN/fullchain.pem $CERT_PATH/cert.pem
            cp $LETSENCRYPT_PATH/live/$FULL_DOMAIN/privkey.pem $CERT_PATH/key.pem
            chmod 600 $CERT_PATH/key.pem
            chmod 644 $CERT_PATH/cert.pem
            echo -e "${GREEN}✅ Let's Encrypt certificate generated successfully${NC}"
            return 0
        fi
    fi
    
    echo -e "${RED}❌ Let's Encrypt certificate generation failed${NC}"
    return 1
}

# Function to generate self-signed certificate (fallback)
generate_self_signed() {
    echo -e "${BLUE}[2/4] Generating self-signed certificate (fallback)...${NC}"
    
    mkdir -p $CERT_PATH
    
    openssl req -x509 -newkey rsa:4096 \
        -keyout $CERT_PATH/key.pem \
        -out $CERT_PATH/cert.pem \
        -days 365 -nodes \
        -subj "/CN=$FULL_DOMAIN"
    
    chmod 600 $CERT_PATH/key.pem
    chmod 644 $CERT_PATH/cert.pem
    
    echo -e "${YELLOW}⚠️ Self-signed certificate generated (temporary)${NC}"
    echo -e "${YELLOW}   Once DNS is fully propagated, run:${NC}"
    echo -e "${YELLOW}   docker-compose -f docker-compose.prod.yml restart nginx${NC}"
}

# Function to configure automatic renewal
setup_renewal_cron() {
    echo -e "${BLUE}[3/4] Configuring automatic renewal...${NC}"
    
    # Create crontab for automatic renewal at 3 AM
    echo "0 3 * * * /usr/local/bin/renew-certs.sh" | crontab -
    
    # Start crond in background
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
        echo -e "${RED}❌ Error in nginx configuration${NC}"
        nginx -t  # Show the full error
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
    echo -e "${YELLOW}⚠️ Let's Encrypt failed, falling back to self-signed${NC}"
    generate_self_signed
fi

echo ""

# Setup automatic renewal
setup_renewal_cron

# Validate nginx
validate_nginx

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Initialization completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}📋 Certificate Information:${NC}"
if [ -f "$CERT_PATH/cert.pem" ]; then
    echo "  Certificate: $(ls -lh $CERT_PATH/cert.pem | awk '{print $5}')"
    EXPIRY=$(openssl x509 -in $CERT_PATH/cert.pem -noout -enddate | cut -d= -f2)
    echo "  Expires: $EXPIRY"
else
    echo "  No certificate found"
fi
echo ""

# Execute main command (nginx)
exec "$@"