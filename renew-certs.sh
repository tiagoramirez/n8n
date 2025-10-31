DOMAIN=${DOMAIN:-"tiagoramirez.lat"}
SUBDOMAIN=${SUBDOMAIN:-"n8n"}
FULL_DOMAIN="$SUBDOMAIN.$DOMAIN"
CERT_PATH="/etc/nginx/ssl"
LETSENCRYPT_PATH="/etc/letsencrypt"

echo "[$(date)] Initializing certificate renewal..."

# Renew with certbot
certbot renew --quiet

# Verify if new certificates are available
if [ -f "$LETSENCRYPT_PATH/live/$FULL_DOMAIN/fullchain.pem" ]; then
    # Copy certificates
    cp $LETSENCRYPT_PATH/live/$FULL_DOMAIN/fullchain.pem $CERT_PATH/cert.pem
    cp $LETSENCRYPT_PATH/live/$FULL_DOMAIN/privkey.pem $CERT_PATH/key.pem
    chmod 600 $CERT_PATH/key.pem
    chmod 644 $CERT_PATH/cert.pem
    
    # Reload nginx (no downtime)
    nginx -s reload
    
    echo "[$(date)] ✅ Certificates renewed and nginx reloaded"
else
    echo "[$(date)] ⚠️ No new certificates available"
fi