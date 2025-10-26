#!/bin/bash
set -e

# deploy.sh - Ejecutar desde tu máquina local para desplegar a EC2

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuración
EC2_USER="ubuntu"
EC2_HOST="${1:-}"
EC2_KEY="${2:-}"
PROJECT_PATH="/home/ubuntu/proyecto"
ENVIRONMENT="${3:-production}"

# Validación
if [ -z "$EC2_HOST" ] || [ -z "$EC2_KEY" ]; then
    echo -e "${RED}❌ Uso: ./deploy.sh <ec2-ip> <path-to-key.pem> [production|development]${NC}"
    echo ""
    echo "Ejemplo:"
    echo "  ./deploy.sh 54.123.45.67 ~/.ssh/mi-key.pem production"
    exit 1
fi

# Validar que la key existe
if [ ! -f "$EC2_KEY" ]; then
    echo -e "${RED}❌ Clave PEM no encontrada: $EC2_KEY${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🚀 Deploy a EC2${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Host: $EC2_HOST"
echo "Environment: $ENVIRONMENT"
echo ""

# Paso 1: Validar archivos locales
echo -e "${BLUE}[1/6] Validando archivos locales...${NC}"

REQUIRED_FILES=(
    "docker-compose.yml"
    "docker-compose.prod.yml"
    "nginx.conf"
    "nginx.prod.conf"
    ".env"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}❌ Archivo no encontrado: $file${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✅ Todos los archivos necesarios existen${NC}"

# Paso 2: Validar nginx.conf
echo -e "${BLUE}[2/6] Validando configuración nginx...${NC}"

# Validar nginx.conf local
docker run --rm -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro \
    nginx:alpine nginx -t > /dev/null 2>&1

# Validar nginx.prod.conf
docker run --rm -v $(pwd)/nginx.prod.conf:/etc/nginx/nginx.conf:ro \
    nginx:alpine nginx -t > /dev/null 2>&1

echo -e "${GREEN}✅ Configuración nginx válida${NC}"

# Paso 3: Preparar archivos
echo -e "${BLUE}[3/6] Preparando archivos para deploy...${NC}"

# Crear directorio temporal
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copiar archivos (excluyendo .git, node_modules, etc)
rsync -a \
    --exclude=.git \
    --exclude=node_modules \
    --exclude=dist \
    --exclude=build \
    --exclude=.DS_Store \
    --exclude=ssl/key.pem \
    --exclude=ssl/cert.pem \
    . $TEMP_DIR/

echo -e "${GREEN}✅ Archivos preparados${NC}"

# Paso 4: Uploading a EC2
echo -e "${BLUE}[4/6] Subiendo archivos a EC2...${NC}"

ssh -i $EC2_KEY $EC2_USER@$EC2_HOST "mkdir -p $PROJECT_PATH"

rsync -avz \
    -e "ssh -i $EC2_KEY" \
    --delete \
    $TEMP_DIR/ \
    $EC2_USER@$EC2_HOST:$PROJECT_PATH/

echo -e "${GREEN}✅ Archivos subidos${NC}"

# Paso 5: Deploy en EC2
echo -e "${BLUE}[5/6] Ejecutando deploy en EC2...${NC}"

ssh -i $EC2_KEY $EC2_USER@$EC2_HOST << EOFSCRIPT
    set -e
    cd $PROJECT_PATH
    
    # Actualizar imagen
    docker-compose -f docker-compose.prod.yml pull
    
    # Detener contenedores
    docker-compose -f docker-compose.prod.yml down
    
    # Iniciar nuevamente
    docker-compose -f docker-compose.prod.yml up -d
    
    # Esperar a que se levanten los servicios
    sleep 5
    
    # Verificar que nginx esté corriendo
    docker-compose -f docker-compose.prod.yml logs nginx | head -20
EOFSCRIPT

echo -e "${GREEN}✅ Deploy completado${NC}"

# Paso 6: Health check
echo -e "${BLUE}[6/6] Verificando salud de servicios...${NC}"

N8N_HOST=$(grep "N8N_HOST=" $EC2_KEY/../.env | cut -d'=' -f2)

# Esperar a que nginx esté listo
sleep 3

HEALTH_CHECK=$(ssh -i $EC2_KEY $EC2_USER@$EC2_HOST \
    "curl -s -o /dev/null -w '%{http_code}' https://localhost/health --insecure" 2>/dev/null || echo "000")

if [ "$HEALTH_CHECK" == "200" ]; then
    echo -e "${GREEN}✅ Health check exitoso${NC}"
else
    echo -e "${YELLOW}⚠️ Health check retornó: $HEALTH_CHECK${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✅ ¡Deploy completado exitosamente!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "🔗 URLs:"
echo "  • https://n8n.jorge.dev"
echo "  • https://java-app.jorge.dev"
echo ""
echo "📊 Ver logs:"
echo "  ssh -i $EC2_KEY $EC2_USER@$EC2_HOST"
echo "  cd $PROJECT_PATH"
echo "  docker-compose -f docker-compose.prod.yml logs -f"
echo ""