# Dockerfile
FROM nginx:alpine

# Instalar certbot y otras herramientas
RUN apk add --no-cache \
    certbot \
    certbot-nginx \
    bash \
    curl \
    dcron \
    openssl

# Copiar configuración nginx
COPY nginx.prod.conf /etc/nginx/nginx.conf

# Crear directorios
RUN mkdir -p /var/www/certbot /etc/nginx/ssl

# Copiar scripts
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY renew-certs.sh /usr/local/bin/renew-certs.sh

# Permisos
RUN chmod +x /docker-entrypoint.sh /usr/local/bin/renew-certs.sh

# Health check
# HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
#     CMD curl -f http://localhost/health || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]