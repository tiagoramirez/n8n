# n8n

## Development

### 1. Setup environment:

 - Create `.env` file based on `.env.example` template.

### 2. Start docker compose:

```bash
docker-compose up -d
```

### 3.1 Access n8n: http://localhost:5678/

### 3.2 Reload nginx

```bash
docker-compose exec nginx nginx -s reload
```

### 4. Stop docker compose:

```bash
docker-compose stop
```

## Production

### 1. Clone repository into EC2 instance

### 2. Setup environment:

 - Create `.env` file based on `.env.example` template.

### 3. Create SSL certificate:

Certbot in ubuntu example:
```bash
sudo apt update
sudo apt upgrade
sudo apt install certbot
sudo certbot certonly --standalone \
  -d n8n.{domain}
cp /etc/letsencrypt/live/n8n.{domain}/cert.pem ./ssl/
cp /etc/letsencrypt/live/n8n.{domain}/privkey.pem ./ssl/key.pem
cp /etc/letsencrypt/live/n8n.{domain}/chain.pem ./ssl
```
<!-- 
Certbot in ubuntu example with many domains:
sudo certbot certonly --standalone \
  -d subdomain1.{domain} \
  -d subdomain2.{domain}
-->


### 3. Start docker compose:

```bash
docker-compose up -d
```

### 3.1 Access n8n: http://n8n.tiagoramirez.dev/

### 3.2 Reload nginx

```bash
docker-compose exec nginx nginx -s reload
```

### 4. Stop docker compose:

```bash
docker-compose stop
```
