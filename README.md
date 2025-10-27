# n8n

## Development

### 1. Clone repository

### 2. Setup environment:

- Create `.env` file based on `.env.example` template.

```bash
cp .env.example .env
```

### 3. Generate auto-signed certificate (just once)

```bash
mkdir -p ssl
openssl req -x509 -newkey rsa:4096 \
  -keyout ssl/key.pem \
  -out ssl/cert.pem \
  -days 365 -nodes \
  -subj "/CN=localhost"
```

### 4. Start docker compose:

```bash
docker-compose up -d
```

### 5 Access n8n: https://n8n.localhost

### 6. Watch logs:

```bash
docker-compose logs -f
```

### 7. Stop docker compose:

```bash
docker-compose stop
```

## Production (AWS)

### 1. Connect to EC2 instance:

`Example with AWS EC2 instance (ubuntu)`
```bash
ssh -i {key_file} ubuntu@{ip_address}
```

### 2. Update system y add pre-requisites:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose
```

### 3. Clone repository into EC2 instance with ssl:

```bash
git clone git@github.com:tiagoramirez/n8n.git
cd /n8n
```

### 4. Setup environment:

- Create `.env` file based on `.env.example` template.

```bash
cp .env.example .env
```

### 5. Start docker compose:

```bash
sudo docker-compose -f docker-compose.prod.yml up -d
```

### 6. Watch logs:

```bash
sudo docker-compose -f docker-compose.prod.yml logs -f nginx
```

### 7. Configure redirection in dns provider.

### 8.1. Access n8n if dns ready: https://n8n.tiagoramirez.lat/

### 8.2. Access n8n if dns not ready: https://<ip_address>/

### 9. Stop docker compose:

```bash
sudo docker-compose -f docker-compose.prod.yml stop
```