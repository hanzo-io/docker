# Hanzo AI Platform - Docker Deployment

Production-ready Docker Compose deployment for Hanzo AI Platform.

## 🚀 Quick Start

### Prerequisites

- Docker Engine 24.0+ with Compose support
- Domain with DNS configured
- DigitalOcean droplet (recommended: `s-8vcpu-16gb-amd`)

### Initial Setup

```bash
# 1. Clone repository
git clone https://github.com/hanzoai/platform
cd platform/docker

# 2. Configure environment
cp .env.example .env
vim .env  # Fill in your values

# 3. Deploy
./deploy.sh deploy
```

## 📦 Images

Published on Docker Hub:

- `hanzoai/gateway:latest` - Inference proxy (Node.js) ~200MB
- `hanzoai/platform:latest` - Manager UI (Next.js) ~464MB
- `hanzoai/nexus:latest` - Orchestrator (Rust) *building*
- `hanzo-node:latest` - Local inference (Python) *building*

## 🏗️ Architecture

```
                    Internet
                       │
                       ↓
                    Caddy (443)
                    ↙     ↘
        Platform (3000)  Gateway (3001)
                ↓            ↓
            PostgreSQL    Redis
                ↓            ↓
            Nexus (8080)  Hanzo-Node (8000)
```

## 🔧 Configuration

### Environment Variables

Required:
- `DOMAIN` - Your domain (e.g., hanzo.ai)
- `ACME_EMAIL` - Email for Let's Encrypt
- `POSTGRES_PASSWORD` - Database password
- `NEXTAUTH_SECRET` - Auth secret (32+ chars)
- `GRAFANA_PASSWORD` - Grafana admin password

Optional:
- `DIGITALOCEAN_API_KEY` - For DO integration
- `DEEPSEEK_API_KEY` - DeepSeek provider
- `OPENAI_API_KEY` - OpenAI provider
- `ANTHROPIC_API_KEY` - Anthropic provider

See [.env.example](.env.example) for full list.

### Domains

Configure DNS A records:
```
platform.hanzo.ai → YOUR_SERVER_IP
gateway.hanzo.ai  → YOUR_SERVER_IP
api.hanzo.ai      → YOUR_SERVER_IP
metrics.hanzo.ai  → YOUR_SERVER_IP
```

## 🚢 Deployment

### Core Services

```bash
./deploy.sh deploy
```

Deploys:
- PostgreSQL (database)
- Redis (cache)
- Gateway (inference proxy)
- Platform (management UI)
- Caddy (reverse proxy + SSL)

### Optional Services

#### Monitoring

```bash
./deploy.sh monitoring
```

Adds:
- Prometheus (metrics)
- Grafana (dashboards)

Access: `https://metrics.hanzo.ai`

#### Local Inference

```bash
./deploy.sh inference
```

Adds:
- Hanzo-Node (local LLM inference)

Requires:
- GPU (NVIDIA) or CPU with 16GB+ RAM
- Model files in `/models` volume

## 📊 Management

### View Status

```bash
./deploy.sh status
```

### View Logs

```bash
# All services
./deploy.sh logs

# Specific service
./deploy.sh logs gateway

# Follow
docker compose -f compose.yml logs -f
```

### Restart Service

```bash
./deploy.sh restart gateway
./deploy.sh restart platform
```

### Stop All

```bash
./deploy.sh stop
```

### Remove All

```bash
./deploy.sh down
```

## 🔨 Development

### Local Development

```bash
# Start with dev overrides
docker compose -f compose.yml -f compose.dev.yml up

# Or manually
cd ..
make dev-gateway    # Terminal 1
make dev-platform   # Terminal 2
```

### Build Custom Images

```bash
# Gateway
cd ../gateway
docker build -f docker/Dockerfile -t hanzoai/gateway:custom .

# Platform
cd ../platform
docker build -f docker/Dockerfile -t hanzoai/platform:custom .

# Use custom images
docker compose -f compose.yml up -d
```

## 📈 Scaling

### Horizontal Scaling

```bash
# Scale gateway to 5 replicas
docker compose -f compose.yml up -d --scale gateway=5

# Scale platform to 3 replicas
docker compose -f compose.yml up -d --scale platform=3
```

### Resource Limits

Edit `compose.yml`:

```yaml
services:
  gateway:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

## 🔒 Security

### SSL Certificates

Caddy automatically provisions Let's Encrypt certificates.

View certificates:
```bash
docker compose -f compose.yml exec caddy caddy trust
```

### Secrets Management

Never commit `.env` to git. Use:

```bash
# Docker secrets (Swarm)
echo "my-password" | docker secret create db_password -

# Or environment variables
export POSTGRES_PASSWORD="$(openssl rand -base64 32)"
```

### Firewall

```bash
# UFW
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw enable
```

## 🐛 Troubleshooting

### Service Unhealthy

```bash
# Check logs
docker compose -f compose.yml logs gateway

# Restart service
docker compose -f compose.yml restart gateway

# Force recreate
docker compose -f compose.yml up -d --force-recreate gateway
```

### Database Connection Issues

```bash
# Check PostgreSQL
docker compose -f compose.yml exec postgres pg_isready -U hanzo

# View connections
docker compose -f compose.yml exec postgres psql -U hanzo -c "SELECT * FROM pg_stat_activity;"
```

### Redis Connection Issues

```bash
# Check Redis
docker compose -f compose.yml exec redis redis-cli ping

# View info
docker compose -f compose.yml exec redis redis-cli info
```

### SSL Certificate Issues

```bash
# Check Caddy logs
docker compose -f compose.yml logs caddy

# Force renewal
docker compose -f compose.yml exec caddy caddy reload --force
```

## 📚 Additional Resources

- [Compose Specification](https://compose-spec.io/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Let's Encrypt](https://letsencrypt.org/)

## 🆘 Support

- GitHub Issues: https://github.com/hanzoai/platform/issues
- Discord: https://discord.gg/hanzoai
- Email: support@hanzo.ai

## 📝 License

MIT License - see LICENSE file for details.
