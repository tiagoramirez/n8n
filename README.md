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
ssh -i ~/.ssh/{key_name} ubuntu@{ip_address}
```

### 2. Clone repository into EC2 instance with ssl:

```bash
sudo git clone git@github.com:tiagoramirez/n8n.git
```

### 3. Setup environment:

- Create `.env` file based on `.env.example` template.

```bash
cp .env.example .env
```

### 4.1. Start docker compose:

```bash
docker-compose -f docker-compose.prod.yml up -d
```

### 4.2. Start docker compose with logs:

```bash
docker-compose -f docker-compose.prod.yml logs -f nginx
```

### 5. Access n8n: http://n8n.tiagoramirez.lat/

### 6. Stop docker compose:

```bash
docker-compose -f docker-compose.prod.yml stop
```