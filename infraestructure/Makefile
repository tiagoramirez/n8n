# Makefile

.PHONY: help local-setup local-up local-down prod-setup prod-deploy prod-logs clean

help:
	@echo "🚀 Proyecto Jorge - Comandos disponibles"
	@echo ""
	@echo "Desarrollo Local:"
	@echo "  make local-setup     - Preparar desarrollo local"
	@echo "  make local-up        - Levantar servicios locales"
	@echo "  make local-down      - Detener servicios locales"
	@echo "  make local-logs      - Ver logs locales"
	@echo ""
	@echo "Producción (EC2):"
	@echo "  make prod-setup      - Setup inicial en EC2"
	@echo "  make prod-deploy     - Deploy a EC2"
	@echo "  make prod-logs       - Ver logs en EC2"
	@echo "  make prod-renew-ssl  - Renovar certificados en EC2"
	@echo ""
	@echo "General:"
	@echo "  make clean           - Limpiar todo"

local-setup:
	@echo "🔧 Preparando desarrollo local..."
	@cp .env.example .env || true
	@if [ ! -f ssl/cert.pem ]; then \
		mkdir -p ssl; \
		openssl req -x509 -newkey rsa:4096 \
			-keyout ssl/key.pem \
			-out ssl/cert.pem \
			-days 365 -nodes \
			-subj "/CN=localhost"; \
	fi
	@echo "✅ Setup completado"
	@echo "Próximo: make local-up"

local-up:
	@docker-compose up -d
	@echo "✅ Servicios levantados"
	@echo "Accede a:"
	@echo "  • https://n8n.localhost (advertencia SSL es normal)"
	@echo "  • https://java-app.localhost"

local-down:
	@docker-compose down
	@echo "✅ Servicios detenidos"

local-logs:
	@docker-compose logs -f

prod-setup:
	@echo "Ingresa IP de EC2:"
	@read EC2_IP; \
	chmod +x setup-ec2.sh; \
	scp -i ${EC2_KEY} setup-ec2.sh ubuntu@$$EC2_IP:/home/ubuntu/; \
	ssh -i ${EC2_KEY} ubuntu@$$EC2_IP "./setup-ec2.sh"

prod-deploy:
	@if [ -z "$(EC2_IP)" ] || [ -z "$(EC2_KEY)" ]; then \
		echo "❌ Debes definir: make prod-deploy EC2_IP=x.x.x.x EC2_KEY=/path/key.pem"; \
		exit 1; \
	fi
	@chmod +x deploy.sh
	@./deploy.sh $(EC2_IP) $(EC2_KEY)

prod-logs:
	@if [ -z "$(EC2_IP)" ] || [ -z "$(EC2_KEY)" ]; then \
		echo "❌ Debes definir: make prod-logs EC2_IP=x.x.x.x EC2_KEY=/path/key.pem"; \
		exit 1; \
	fi
	@ssh -i $(EC2_KEY) ubuntu@$(EC2_IP) "cd /home/ubuntu/proyecto && docker-compose -f docker-compose.prod.yml logs -f"

prod-renew-ssl:
	@if [ -z "$(EC2_IP)" ] || [ -z "$(EC2_KEY)" ]; then \
		echo "❌ Debes definir: make prod-renew-ssl EC2_IP=x.x.x.x EC2_KEY=/path/key.pem"; \
		exit 1; \
	fi
	@chmod +x renew-ssl.sh
	@scp -i $(EC2_KEY) renew-ssl.sh ubuntu@$(EC2_IP):/home/ubuntu/
	@ssh -i $(EC2_KEY) ubuntu@$(EC2_IP) "bash /home/ubuntu/renew-ssl.sh"

clean:
	@docker-compose down -v
	@rm -rf ssl/cert.pem ssl/key.pem
	@echo "✅ Limpieza completada"