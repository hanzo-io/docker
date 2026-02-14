# 🚀 Hanzo AI Platform - Complete Deployment Guide

## 📋 Table of Contents

1. [Overview](#overview)
2. [What's Ready](#whats-ready)
3. [Deployment Methods](#deployment-methods)
4. [DigitalOcean Setup](#digitalocean-setup)
5. [Configuration](#configuration)
6. [Deployment](#deployment)
7. [Verification](#verification)
8. [Monitoring](#monitoring)
9. [Maintenance](#maintenance)

---

## Overview

This guide covers deploying the complete Hanzo AI Platform stack to production using modern Docker Compose (Compose Spec).

### Stack Components

| Component | Image | Size | Status | Purpose |
|-----------|-------|------|--------|---------|
| Gateway | `hanzoai/gateway:latest` | 200MB | ✅ Live | Inference proxy, free tier |
| Platform | `hanzoai/platform:latest` | 464MB | ✅ Live | Management UI v4.0.6 |
| Nexus | `hanzoai/nexus:latest` | TBD | 🔨 Building | Request orchestrator |
| Hanzo-Node | `hanzo-node:latest` | TBD | 🔨 Building | Local LLM inference |

Supporting services:
- PostgreSQL 16 (database)
- Redis 7 (cache/rate limiting)
- Caddy 2 (reverse proxy + SSL)
- Prometheus (metrics)
- Grafana (dashboards)

---

## What's Ready

### ✅ Completed

1. **Docker Images** (Published)
   - hanzoai/gateway:latest
   - hanzoai/platform:latest

2. **Infrastructure as Code**
   - `compose.yml` - Production stack
   - `compose.dev.yml` - Development overrides
   - `caddy/Caddyfile` - Reverse proxy config
   - `prometheus/prometheus.yml` - Metrics config
   - `.env.example` - Environment template

3. **Automation**
   - `deploy.sh` - Deployment automation
   - Health checks
   - Auto-scaling support

4. **Documentation**
   - README.md - Full guide
   - QUICKSTART.md - 5-minute setup
   - DEPLOYMENT_READY.md - Status & architecture

### ⏳ In Progress

- hanzo-node:latest (~20 min)
- hanzoai/nexus:latest (pending)

**You can deploy NOW without these!** They're optional enhancements.

---

## Deployment Methods

### Method 1: Quick Deploy (Recommended)

For immediate deployment with core services:

```bash
# 1. Clone and configure
git clone https://github.com/hanzoai/platform
cd platform/docker
cp .env.example .env
vim .env

# 2. Deploy
./deploy.sh deploy

# 3. Verify
./deploy.sh status
```

**Time: 5-10 minutes**

### Method 2: Manual Deploy

For custom configurations:

```bash
# Pull images
docker compose -f compose.yml pull

# Start services
docker compose -f compose.yml up -d

# Check health
docker compose -f compose.yml ps
```

### Method 3: Development Mode

For local testing:

```bash
docker compose -f compose.yml -f compose.dev.yml up
```

Access at http://localhost:3000

---

## DigitalOcean Setup

### 1. Create Droplet

```bash
# Install doctl
brew install doctl  # macOS
# or: https://docs.digitalocean.com/reference/doctl/how-to/install/

# Authenticate
doctl auth init

# Create droplet
doctl compute droplet create hanzo-platform \
  --region sfo3 \
  --size s-8vcpu-16gb-amd \
  --image docker-20-04 \
  --ssh-keys $(doctl compute ssh-key list --format ID --no-header | head -1) \
  --enable-monitoring \
  --enable-ipv6 \
  --tag-names hanzo,platform,production \
  --wait
```

**Recommended sizes:**

| Size | vCPU | RAM | Disk | Price/mo | Use Case |
|------|------|-----|------|----------|----------|
| s-4vcpu-8gb-amd | 4 | 8GB | 160GB | $48 | Testing |
| s-8vcpu-16gb-amd | 8 | 16GB | 320GB | $96 | Production |
| g-8vcpu-32gb | 8 | 32GB | 100GB | $168 | + Inference |

### 2. Configure Firewall

```bash
# Create firewall
doctl compute firewall create \
  --name hanzo-platform \
  --inbound-rules "protocol:tcp,ports:22,sources:addresses:YOUR_IP protocol:tcp,ports:80,sources:addresses:0.0.0.0/0 protocol:tcp,ports:443,sources:addresses:0.0.0.0/0" \
  --outbound-rules "protocol:tcp,ports:all,destinations:addresses:0.0.0.0/0 protocol:udp,ports:all,destinations:addresses:0.0.0.0/0"

# Apply to droplet
doctl compute firewall add-droplets FIREWALL_ID --droplet-ids DROPLET_ID
```

Or via web UI:
1. Navigate to Networking → Firewalls
2. Create firewall with rules:
   - Inbound: SSH (22), HTTP (80), HTTPS (443)
   - Outbound: All

### 3. Configure DNS

Add A records for your domain:

```
Type  Name      Value           TTL
A     platform  DROPLET_IP      3600
A     gateway   DROPLET_IP      3600  
A     api       DROPLET_IP      3600
A     metrics   DROPLET_IP      3600
```

**Verify DNS:**
```bash
dig platform.hanzo.ai +short
# Should return: DROPLET_IP
```

---

## Configuration

### Environment Variables

Create `.env` from template:

```bash
cp .env.example .env
```

**Required variables:**

```bash
# Domain
DOMAIN=hanzo.ai
ACME_EMAIL=admin@hanzo.ai

# Secrets (generate with openssl rand -base64 32)
POSTGRES_PASSWORD=YOUR_SECURE_PASSWORD
NEXTAUTH_SECRET=YOUR_SECURE_SECRET
GRAFANA_PASSWORD=YOUR_SECURE_PASSWORD

# Optional: Provider API Keys
DIGITALOCEAN_API_KEY=
DEEPSEEK_API_KEY=
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
```

**Generate secure secrets:**

```bash
# One-liner to populate secrets
sed -i '' \
  -e "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -base64 32)/" \
  -e "s/NEXTAUTH_SECRET=.*/NEXTAUTH_SECRET=$(openssl rand -base64 32)/" \
  -e "s/GRAFANA_PASSWORD=.*/GRAFANA_PASSWORD=$(openssl rand -base64 16)/" \
  .env
```

### Compose Profiles

Enable optional services with profiles:

```bash
# Include monitoring
docker compose --profile monitoring up -d

# Include inference
docker compose --profile inference up -d

# Include both
docker compose --profile monitoring --profile inference up -d
```

---

## Deployment

### Step-by-Step Deployment

#### 1. SSH to Server

```bash
# Get droplet IP
doctl compute droplet list --format Name,PublicIPv4

# SSH
ssh root@DROPLET_IP
```

#### 2. Clone Repository

```bash
cd /opt
git clone https://github.com/hanzoai/platform
cd platform/docker
```

#### 3. Configure Environment

```bash
cp .env.example .env
vim .env
# Fill in your values
```

#### 4. Deploy Services

```bash
# Make deploy script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh deploy
```

The script will:
- ✓ Check requirements
- ✓ Validate environment
- ✓ Pull Docker images
- ✓ Initialize database
- ✓ Start services
- ✓ Check health
- ✓ Display status

#### 5. Watch Logs

```bash
# All services
./deploy.sh logs

# Specific service
./deploy.sh logs gateway

# Follow live
docker compose -f compose.yml logs -f
```

---

## Verification

### Health Checks

```bash
# Check all services
./deploy.sh status

# Manual health checks
curl https://platform.hanzo.ai/api/health
curl https://gateway.hanzo.ai/health

# Check SSL
curl -I https://platform.hanzo.ai
```

### Service Access

Once deployed, access:

- **Platform UI**: https://platform.hanzo.ai
- **Gateway API**: https://gateway.hanzo.ai
- **Metrics**: https://metrics.hanzo.ai

### Test API

```bash
# Test gateway
curl -X POST https://gateway.hanzo.ai/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Database Connection

```bash
# From host
docker compose -f compose.yml exec postgres psql -U hanzo -c "SELECT version();"

# Check connections
docker compose -f compose.yml exec postgres psql -U hanzo -c "SELECT count(*) FROM pg_stat_activity;"
```

---

## Monitoring

### Deploy Monitoring Stack

```bash
./deploy.sh monitoring
```

This adds:
- Prometheus (metrics collection)
- Grafana (dashboards)

Access: https://metrics.hanzo.ai

### Default Credentials

- Username: `admin`
- Password: `$GRAFANA_PASSWORD` (from .env)

### Key Metrics

- Request rate (requests/sec)
- Error rate (%)
- Latency (p50, p95, p99)
- Resource usage (CPU, memory)
- Cache hit rate

### Prometheus Queries

Access Prometheus via SSH tunnel:

```bash
# Create tunnel
ssh -L 9090:localhost:9090 root@DROPLET_IP

# Access
open http://localhost:9090
```

Useful queries:
```promql
# Request rate
rate(http_requests_total[5m])

# Error rate
rate(http_requests_total{status=~"5.."}[5m]) 
/ rate(http_requests_total[5m])

# Latency P95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

---

## Maintenance

### Backups

#### Database

```bash
# Manual backup
docker compose -f compose.yml exec postgres \
  pg_dump -U hanzo hanzo | gzip > backup-$(date +%Y%m%d).sql.gz

# Automated backup (add to cron)
0 3 * * * cd /opt/platform/docker && docker compose exec -T postgres pg_dump -U hanzo hanzo | gzip > /backups/hanzo-$(date +\%Y\%m\%d).sql.gz
```

#### Volumes

```bash
# Backup all volumes
docker compose -f compose.yml down
tar czf volumes-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/docker/volumes/hanzo-platform_*
docker compose -f compose.yml up -d
```

### Updates

#### Update Images

```bash
# Pull latest images
docker compose -f compose.yml pull

# Restart with new images
docker compose -f compose.yml up -d

# Remove old images
docker image prune -a -f
```

#### Update Configuration

```bash
# Edit config
vim compose.yml

# Apply changes
docker compose -f compose.yml up -d
```

### Scaling

#### Horizontal Scaling

```bash
# Scale gateway to 5 replicas
docker compose -f compose.yml up -d --scale gateway=5

# Scale platform to 3 replicas
docker compose -f compose.yml up -d --scale platform=3

# Verify
docker compose -f compose.yml ps
```

#### Resource Limits

Edit `compose.yml`:

```yaml
services:
  gateway:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

Apply:
```bash
docker compose -f compose.yml up -d --force-recreate
```

### Logs

#### View Logs

```bash
# All services
docker compose -f compose.yml logs

# Specific service
docker compose -f compose.yml logs gateway

# Follow
docker compose -f compose.yml logs -f

# Last 100 lines
docker compose -f compose.yml logs --tail=100
```

#### Log Rotation

Caddy handles its own rotation. For Docker logs:

```bash
# Add to /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  }
}

# Restart Docker
systemctl restart docker
```

### Troubleshooting

#### Service Won't Start

```bash
# Check logs
docker compose -f compose.yml logs SERVICE_NAME

# Check health
docker compose -f compose.yml ps SERVICE_NAME

# Force recreate
docker compose -f compose.yml up -d --force-recreate SERVICE_NAME
```

#### Database Connection Errors

```bash
# Check PostgreSQL
docker compose -f compose.yml exec postgres pg_isready -U hanzo

# Check connections
docker compose -f compose.yml exec postgres psql -U hanzo -c "SELECT * FROM pg_stat_activity;"

# Restart
docker compose -f compose.yml restart postgres
```

#### SSL Certificate Issues

```bash
# Check Caddy logs
docker compose -f compose.yml logs caddy

# Verify DNS
dig platform.hanzo.ai +short

# Force renewal
docker compose -f compose.yml exec caddy caddy reload --force
```

#### High Memory Usage

```bash
# Check resource usage
docker stats

# Check limits
docker compose -f compose.yml config

# Adjust limits in compose.yml
```

---

## Summary

You now have:

✅ Production-ready Docker Compose configuration
✅ Automatic HTTPS with Let's Encrypt
✅ Load balancing and scaling
✅ Health checks and monitoring
✅ Secure by default
✅ Easy maintenance

**Total deployment time: 5-10 minutes**

Next steps:
1. Deploy core services (gateway + platform)
2. Configure monitoring
3. Add inference when hanzo-node is ready
4. Set up automated backups
5. Configure alerting

Need help? 
- Full docs: [README.md](README.md)
- Quick start: [QUICKSTART.md](QUICKSTART.md)
- Issues: https://github.com/hanzoai/platform/issues
