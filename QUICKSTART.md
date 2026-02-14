# ⚡ Hanzo AI Platform - 5 Minute Deployment

## Prerequisites

- Docker Engine 24.0+ with Compose support
- Domain with DNS configured (or use IP for testing)
- Server with 8GB+ RAM

## Deploy in 5 Minutes

### 1. Clone & Configure (1 min)

```bash
git clone https://github.com/hanzoai/platform
cd platform/docker
cp .env.example .env
```

Edit `.env`:
```bash
DOMAIN=hanzo.ai
ACME_EMAIL=admin@hanzo.ai
POSTGRES_PASSWORD=$(openssl rand -base64 32)
NEXTAUTH_SECRET=$(openssl rand -base64 32)
GRAFANA_PASSWORD=$(openssl rand -base64 16)
```

### 2. Configure DNS (2 min)

Add A records pointing to your server IP:
```
platform.hanzo.ai → YOUR_SERVER_IP
gateway.hanzo.ai  → YOUR_SERVER_IP
api.hanzo.ai      → YOUR_SERVER_IP
```

### 3. Deploy (2 min)

```bash
./deploy.sh deploy
```

That's it! ✨

## Verify

```bash
# Check status
./deploy.sh status

# View logs
./deploy.sh logs

# Test API
curl https://gateway.hanzo.ai/health
```

## URLs

- Platform: https://platform.hanzo.ai
- Gateway API: https://gateway.hanzo.ai
- Metrics: https://metrics.hanzo.ai

## Common Commands

```bash
# View logs
./deploy.sh logs gateway

# Restart service
./deploy.sh restart platform

# Scale up
docker compose -f compose.yml up -d --scale gateway=5

# Stop all
./deploy.sh stop

# Remove all
./deploy.sh down
```

## Add Monitoring

```bash
./deploy.sh monitoring
```

Access: https://metrics.hanzo.ai

## Add Local Inference (requires hanzo-node image)

```bash
./deploy.sh inference
```

## Troubleshooting

### Service unhealthy?
```bash
docker compose -f compose.yml logs SERVICE_NAME
docker compose -f compose.yml restart SERVICE_NAME
```

### SSL not working?
```bash
# Check Caddy logs
docker compose -f compose.yml logs caddy

# Verify DNS
dig platform.hanzo.ai +short
```

### Can't connect to database?
```bash
docker compose -f compose.yml exec postgres pg_isready -U hanzo
```

## Development Mode

```bash
docker compose -f compose.yml -f compose.dev.yml up
```

Access:
- Platform: http://localhost:3000
- Gateway: http://localhost:3001

## Need Help?

- Full docs: [README.md](README.md)
- Issues: https://github.com/hanzoai/platform/issues
- Discord: https://discord.gg/hanzoai
