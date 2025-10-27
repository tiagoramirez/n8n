#!/bin/bash
set -e

# docker-entrypoint.sh - Nginx + Certbot initialization script

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Environment variables
DOMAIN=${DOMAIN:-"tiagoramirez.lat"}
SUBDOMAIN=${SUBDOMAIN:-"n8n"}
FULL_DOMAIN="$SUBDOMAIN.$DOMAIN"
EMAIL=${EMAIL:-"tiagoramirez.dev@pm.me"}
CERT_PATH="/etc/nginx/ssl"
LETSENCRYPT_PATH="/etc/letsencrypt"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🚀 Nginx + Certbot Initialization${NC}"
echo -e "${BLUE}========================================${NC}"

# Function to check certificate expiry
# Returns 0 if renewal is needed, 1 if certificate is still valid
check_cert_expiry() {
    if [ ! -f "$CERT_PATH/cert.pem" ]; then
        echo -e "${YELLOW}⚠️ No certificate found${NC}"
        return 0  # Need to generate certificate
    fi
    
    # Get certificate expiration date
    EXPIRY=$(openssl x509 -in $CERT_PATH/cert.pem -noout -enddate | cut -d= -f2)
    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))
    
    echo -e "${BLUE}Certificate expiry check:${NC}"
    echo "  Expires: $EXPIRY"
    echo "  Days left: $DAYS_LEFT days"
    echo ""
    
    # Renew if less than 30 days left
    if [ $DAYS_LEFT -lt 30 ]; then
        echo -e "${YELLOW}⚠️ Certificate expires in $DAYS_LEFT days, renewal needed${NC}"
        return 0  # Need renewal
    else
        echo -e "${GREEN}✅ Certificate is valid ($DAYS_LEFT days remaining)${NC}"
        return 1  # No renewal needed
    fi
}

# Function to find the correct certificate directory
# Let's Encrypt can store certificates in different paths depending on configuration
find_cert_dir() {
    # Try with the main domain first
    if [ -d "$LETSENCRYPT_PATH/live/$DOMAIN" ]; then
        echo "$LETSENCRYPT_PATH/live/$DOMAIN"
        return 0
    fi
    
    # If not found, try with the subdomain
    if [ -d "$LETSENCRYPT_PATH/live/$FULL_DOMAIN" ]; then
        echo "$LETSENCRYPT_PATH/live/$FULL_DOMAIN"
        return 0
    fi
    
    # Return the expected path (will probably fail)
    echo "$LETSENCRYPT_PATH/live/$FULL_DOMAIN"
    return 1
}

# Function to generate or renew certificates using Let's Encrypt
generate_certs() {
    echo -e "${BLUE}[1/4] Generating/Renewing certificates with Let's Encrypt...${NC}"
    
    mkdir -p $CERT_PATH
    
    # Check if certificate renewal is needed
    if ! check_cert_expiry; then
        echo -e "${GREEN}✅ Certificate is still valid, skipping renewal${NC}"
        
        # Copy existing certificate if located in different path
        CERT_DIR=$(find_cert_dir)
        if [ -f "$CERT_DIR/fullchain.pem" ] && [ ! -f "$CERT_PATH/cert.pem" ]; then
            echo -e "${BLUE}  Copying existing certificate to nginx location...${NC}"
            cp "$CERT_DIR/fullchain.pem" $CERT_PATH/cert.pem
            cp "$CERT_DIR/privkey.pem" $CERT_PATH/key.pem
            chmod 600 $CERT_PATH/key.pem
            chmod 644 $CERT_PATH/cert.pem
            echo -e "${GREEN}✅ Certificate copied successfully${NC}"
        fi
        return 0
    fi
    
    # Certificate needs renewal or is new
    echo -e "${BLUE}  Attempting Let's Encrypt validation...${NC}"
    
    # Use --standalone: Certbot opens its own temporary HTTP server
    # DO NOT use --force-renewal to avoid rate limiting
    certbot certonly \
        --standalone \
        --preferred-challenges http \
        -d $DOMAIN \
        -d $FULL_DOMAIN \
        --email $EMAIL \
        --agree-tos \
        --non-interactive \
        2>&1 | tee /tmp/certbot.log
    
    # Verify if certificate generation was successful
    if grep -q "Successfully received certificate\|Congratulations\|Certificate not yet due for renewal" /tmp/certbot.log; then
        echo -e "${GREEN}✅ Received successful certificate message${NC}"
        
        # Find the correct certificate directory
        CERT_DIR=$(find_cert_dir)
        
        echo -e "${BLUE}  Looking for certificates in: $CERT_DIR${NC}"
        
        # Copy certificates to nginx location
        if [ -f "$CERT_DIR/fullchain.pem" ]; then
            echo -e "${GREEN}✅ Found certificate at: $CERT_DIR${NC}"
            echo -e "${GREEN}✅ Copying certificates to nginx location${NC}"
            
            cp "$CERT_DIR/fullchain.pem" $CERT_PATH/cert.pem
            cp "$CERT_DIR/privkey.pem" $CERT_PATH/key.pem
            chmod 600 $CERT_PATH/key.pem
            chmod 644 $CERT_PATH/cert.pem
            
            echo -e "${GREEN}✅ Let's Encrypt certificate generated successfully${NC}"
            return 0
        else
            echo -e "${RED}❌ Certificate file not found at: $CERT_DIR/fullchain.pem${NC}"
            echo -e "${RED}   Available directories in $LETSENCRYPT_PATH/live/:${NC}"
            ls -la $LETSENCRYPT_PATH/live/ 2>/dev/null || echo "   (none found)"
            return 1
        fi
    fi
    
    echo -e "${RED}❌ Let's Encrypt certificate generation failed${NC}"
    # Check if rate limit was hit
    if grep -q "too many certificates" /tmp/certbot.log; then
        echo -e "${RED}   Rate limit reached. Maximum 5 certificates per week.${NC}"
        echo -e "${RED}   Please wait before retrying.${NC}"
    fi
    return 1
}

# Function to generate self-signed certificate as fallback
# This is used when Let's Encrypt fails (rate limit, network issues, etc)
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
    echo -e "${YELLOW}   This is a fallback certificate.${NC}"
}

# Function to configure automatic certificate renewal via cron
# Certbot will only renew if certificate expires in less than 30 days
setup_renewal_cron() {
    echo -e "${BLUE}[3/4] Configuring automatic renewal...${NC}"
    
    # Create crontab entry to run renewal script daily at 3 AM
    # Certbot will only renew if needed (< 30 days before expiration)
    echo "0 3 * * * /usr/local/bin/renew-certs.sh" | crontab -
    
    # Start crond daemon in background
    crond -f -l 2 &
    CROND_PID=$!
    
    echo -e "${GREEN}✅ Automatic renewal configured (runs daily at 3 AM)${NC}"
}

# Function to validate nginx configuration syntax
validate_nginx() {
    echo -e "${BLUE}[4/4] Validating nginx configuration...${NC}"
    
    nginx -t > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Nginx configuration validated${NC}"
        return 0
    else
        echo -e "${RED}❌ Error in nginx configuration${NC}"
        nginx -t  # Show the full error details
        return 1
    fi
}

# ============ MAIN EXECUTION ============

echo -e "${BLUE}Initializing with parameters:${NC}"
echo "  Domain: $DOMAIN"
echo "  Subdomain: $FULL_DOMAIN"
echo "  Email: $EMAIL"
echo ""

# Try to generate or renew Let's Encrypt certificates
if generate_certs; then
    echo -e "${GREEN}✅ Using Let's Encrypt certificates${NC}"
else
    echo -e "${YELLOW}⚠️ Let's Encrypt failed, falling back to self-signed certificate${NC}"
    generate_self_signed
fi

echo ""

# Setup automatic renewal via cron
setup_renewal_cron

# Validate nginx configuration before starting
validate_nginx

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ Initialization completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}📋 Certificate Information:${NC}"
if [ -f "$CERT_PATH/cert.pem" ]; then
    echo "  Certificate size: $(ls -lh $CERT_PATH/cert.pem | awk '{print $5}')"
    EXPIRY=$(openssl x509 -in $CERT_PATH/cert.pem -noout -enddate | cut -d= -f2)
    echo "  Expires: $EXPIRY"
    
    # Calculate days remaining
    EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
    NOW_EPOCH=$(date +%s)
    DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))
    echo "  Days remaining: $DAYS_LEFT days"
else
    echo "  No certificate found"
fi
echo ""

# Start nginx as the main process (PID 1)
# This allows Docker to manage the container lifecycle
exec "$@"