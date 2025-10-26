#!/bin/bash
set -e

# setup-ec2.sh - Ejecutar UNA SOLA VEZ en EC2

echo "=========================================="
echo "🚀 AWS EC2 Initial Setup"
echo "=========================================="

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
DOMAIN=${1:-"jorge.dev"}
SUBDOMAIN_N8N="n8n.$DOMAIN"
SUBDOMAIN_JAVA="java-app.$DOMAIN"
EMAIL=${2:-"tu@email.com"}
PROJECT_PATH="/home/ubuntu/proyecto"

echo -e "${BLUE}[1/8] Actualizando sistema...${NC}"
sudo apt update
sudo apt upgrade -y
sudo apt install -y git curl wget build-essential

echo -e "${BLUE}[2/8] Instalando Docker...${NC}"
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
rm get-docker.sh

echo -e "${BLUE}[3/8] Instalando Docker Compose...${NC}"
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

echo -e "${BLUE}[4/8] Instalando Certbot...${NC}"
sudo apt install -y certbot python3-certbot-nginx

echo -e "${BLUE}[5/8] Clonando repositorio...${NC}"
mkdir -p $PROJECT_PATH
cd $PROJECT_PATH

# Si ya existe, pull
if [ -d .git ]; then
    git pull origin main
else
    echo "Ingresa tu URL de repositorio git:"
    read GIT_URL
    git clone $GIT_URL .
fi

echo -e "${BLUE}[6/8] Creando estructura SSL...${NC}"
mkdir -p ssl
chmod 700 ssl

echo -e "${BLUE}[7/8] Generando certificado Let's Encrypt...${NC}"
sudo certbot certonly --standalone \
  -d $DOMAIN \
  -d $SUBDOMAIN_N8N \
  -d $SUBDOMAIN_JAVA \
  --agree-tos \
  -m $EMAIL \
  -n

# Copiar certificados
sudo cp /etc/letsencrypt/live/$SUBDOMAIN_N8N/fullchain.pem ssl/cert.pem
sudo cp /etc/letsencrypt/live/$SUBDOMAIN_N8N/privkey.pem ssl/key.pem
sudo chown ubuntu:ubuntu ssl/*.pem
chmod 600 ssl/key.pem
chmod 644 ssl/cert.pem

echo -e "${BLUE}[8/8] Configurando archivo .env...${NC}"
if [ ! -f .env ]; then
    cat > .env << EOF
NODE_ENV=production
N8N_HOST=$SUBDOMAIN_N8N
N8N_PROTOCOL=https
JAVA_APP_HOST=$SUBDOMAIN_JAVA
GENERIC_TIMEZONE=America/Argentina/Buenos_Aires
TZ=America/Argentina/Buenos_Aires
EOF
    echo "✅ .env creado"
else
    echo "⚠️ .env ya existe"
fi

echo -e "${BLUE}[9/10] Preparando certificados para renovación automática...${NC}"
sudo tee /usr/local/bin/renew-certs.sh > /dev/null << 'EOF'
#!/bin/bash
PROJECT_PATH="/home/ubuntu/proyecto"
DOMAIN="jorge.dev"
SUBDOMAIN_N8N="n8n.$DOMAIN"

certbot renew --quiet

# Copiar nuevos certificados
cp /etc/letsencrypt/live/$SUBDOMAIN_N8N/fullchain.pem $PROJECT_PATH/ssl/cert.pem
cp /etc/letsencrypt/live/$SUBDOMAIN_N8N/privkey.pem $PROJECT_PATH/ssl/key.pem
chown ubuntu:ubuntu $PROJECT_PATH/ssl/*.pem
chmod 600 $PROJECT_PATH/ssl/key.pem
chmod 644 $PROJECT_PATH/ssl/cert.pem

# Reiniciar nginx
cd $PROJECT_PATH
docker-compose -f docker-compose.prod.yml restart nginx
EOF

sudo chmod +x /usr/local/bin/renew-certs.sh

echo -e "${BLUE}[10/10] Configurando cron para renovación de certificados...${NC}"
(sudo crontab -l 2>/dev/null || true; echo "0 3 * * * /usr/local/bin/renew-certs.sh") | sudo crontab -

echo -e "${GREEN}✅ Setup completado!${NC}"
echo ""
echo "Próximos pasos:"
echo "1. cd $PROJECT_PATH"
echo "2. docker-compose -f docker-compose.prod.yml up -d"
echo "3. Verifica: curl https://$SUBDOMAIN_N8N"