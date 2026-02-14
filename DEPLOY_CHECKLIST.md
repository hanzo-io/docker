# 🚀 Deployment Checklist - platform.hanzo.ai + gateway.hanzo.ai

## Pre-Deployment

### ✅ 1. DigitalOcean API Key
```bash
# Get your DO API key
# https://cloud.digitalocean.com/account/api/tokens

export DO_API_KEY="dop_v1_..."
```

### ✅ 2. Create Droplet
```bash
# Using doctl
doctl auth init --access-token $DO_API_KEY

doctl compute droplet create hanzo-platform \
  --region sfo3 \
  --size s-8vcpu-16gb-amd \
  --image docker-20-04 \
  --ssh-keys $(doctl compute ssh-key list --format ID --no-header | head -1) \
  --enable-monitoring \
  --wait

# Get IP
export DROPLET_IP=$(doctl compute droplet list --format Name,PublicIPv4 --no-header | grep hanzo-platform | awk '{print $2}')
echo "Droplet IP: $DROPLET_IP"
```

**Or via web UI:**
1. https://cloud.digitalocean.com/droplets/new
2. Choose: Docker 20.04, 16GB RAM, SFO3
3. Create → Get IP

### ✅ 3. Configure DNS

Add A records:
```
Type  Name      Value        TTL
A     platform  $DROPLET_IP  3600
A     gateway   $DROPLET_IP  3600
A     api       $DROPLET_IP  3600
```

Verify:
```bash
dig platform.hanzo.ai +short
dig gateway.hanzo.ai +short
# Both should return: $DROPLET_IP
```

---

## Deployment

### ✅ 4. SSH to Droplet

```bash
ssh root@$DROPLET_IP
```

### ✅ 5. Clone Repository

```bash
cd /opt
git clone https://github.com/hanzoai/platform
cd platform/docker
```

### ✅ 6. Configure Environment

```bash
# Copy template
cp .env.example .env

# Generate secure passwords
export POSTGRES_PASS=$(openssl rand -base64 32)
export NEXTAUTH_SECRET=$(openssl rand -base64 32)
export GRAFANA_PASS=$(openssl rand -base64 16)

# Update .env
cat > .env << EOF
# Domain
DOMAIN=hanzo.ai
ACME_EMAIL=admin@hanzo.ai

# Security
POSTGRES_PASSWORD=$POSTGRES_PASS
NEXTAUTH_SECRET=$NEXTAUTH_SECRET
GRAFANA_PASSWORD=$GRAFANA_PASS

# DigitalOcean + Gradient AI (REQUIRED)
DIGITALOCEAN_API_KEY=$DO_API_KEY
GRADIENT_AI_ENDPOINT=https://api.gradient.ai/v1

# Optional: Additional providers
DEEPSEEK_API_KEY=
OPENAI_API_KEY=
ANTHROPIC_API_KEY=

# Local inference (disabled - no GPU)
ENABLE_LOCAL_NODE=false
EOF

# Show config (verify)
cat .env
```

### ✅ 7. Deploy Services

```bash
# Make deploy script executable
chmod +x deploy.sh

# Deploy!
./deploy.sh deploy
```

**Expected output:**
```
[INFO] Checking requirements...
[INFO] ✓ Requirements met
[INFO] Validating environment...
[INFO] ✓ Environment validated
[INFO] Pulling Docker images...
[INFO] ✓ Images pulled
[INFO] Initializing database...
[INFO] Waiting for PostgreSQL...
[INFO] ✓ PostgreSQL ready
[INFO] Deploying Hanzo AI Platform...
[INFO] ✓ All services healthy
```

### ✅ 8. Check Status

```bash
./deploy.sh status
```

Expected services:
```
NAME                  STATUS   PORTS
hanzo-postgres        Up       5432
hanzo-redis           Up       6379
hanzo-gateway-1       Up       3001
hanzo-gateway-2       Up       3001
hanzo-platform-1      Up       3000
hanzo-platform-2      Up       3000
hanzo-caddy           Up       443, 80
```

---

## Verification

### ✅ 9. Test Endpoints

```bash
# Health checks (from droplet)
curl -v http://localhost:3001/health  # Gateway
curl -v http://localhost:3000/api/health  # Platform

# Public endpoints (wait 2 min for SSL)
sleep 120
curl -v https://gateway.hanzo.ai/health
curl -v https://platform.hanzo.ai/api/health
```

### ✅ 10. Test Gateway API

```bash
# Test inference routing
curl -X POST https://gateway.hanzo.ai/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer test" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Hello from Hanzo!"}]
  }'
```

### ✅ 11. Access Platform UI

```bash
# Open in browser
echo "Platform URL: https://platform.hanzo.ai"
```

1. Create account
2. Verify email
3. Get API key
4. Test with gateway

---

## Post-Deployment

### ✅ 12. View Logs

```bash
# All services
./deploy.sh logs

# Specific service
./deploy.sh logs gateway
./deploy.sh logs platform

# Follow live
docker compose -f compose.yml logs -f gateway
```

### ✅ 13. Monitor Resources

```bash
# Check resource usage
docker stats

# Check disk space
df -h

# Check service health
docker compose -f compose.yml ps
```

### ✅ 14. Enable Monitoring (Optional)

```bash
./deploy.sh monitoring

# Access Grafana
echo "Grafana URL: https://metrics.hanzo.ai"
echo "Username: admin"
echo "Password: $GRAFANA_PASS"
```

---

## Load Balancing

### Current Setup (Automatic)

Your deployment **already has load balancing**:

```yaml
gateway:
  deploy:
    replicas: 2  # ← Docker load balances between these
```

Docker automatically distributes requests between gateway replicas.

### Scale Up (Single Droplet)

```bash
# Add more gateway instances
docker compose -f compose.yml up -d --scale gateway=8

# Add more platform instances
docker compose -f compose.yml up -d --scale platform=4

# Verify
docker compose -f compose.yml ps
```

### Multi-Droplet (When Needed)

See [LOAD_BALANCING.md](LOAD_BALANCING.md) for:
- DigitalOcean Load Balancer setup
- Docker Swarm configuration
- Advanced scaling strategies

**When to scale out:**
- \> 5000 req/sec
- \> 50,000 concurrent users
- High availability requirements

---

## Troubleshooting

### Gateway Not Responding

```bash
# Check logs
docker compose -f compose.yml logs gateway

# Check environment
docker compose -f compose.yml exec gateway env | grep DIGITALOCEAN

# Restart
docker compose -f compose.yml restart gateway
```

### Platform Not Loading

```bash
# Check logs
docker compose -f compose.yml logs platform

# Check database connection
docker compose -f compose.yml exec postgres pg_isready -U hanzo

# Restart
docker compose -f compose.yml restart platform
```

### SSL Certificate Issues

```bash
# Check Caddy logs
docker compose -f compose.yml logs caddy

# Verify DNS
dig platform.hanzo.ai +short
dig gateway.hanzo.ai +short

# Force renewal
docker compose -f compose.yml restart caddy

# Wait for Let's Encrypt (2 min)
sleep 120
curl -I https://platform.hanzo.ai
```

### Database Connection Errors

```bash
# Check PostgreSQL
docker compose -f compose.yml exec postgres pg_isready -U hanzo

# Check connections
docker compose -f compose.yml exec postgres \
  psql -U hanzo -c "SELECT count(*) FROM pg_stat_activity;"

# Check logs
docker compose -f compose.yml logs postgres

# Restart
docker compose -f compose.yml restart postgres
```

---

## Maintenance

### Update Images

```bash
# Pull latest
docker compose -f compose.yml pull

# Restart with new images
docker compose -f compose.yml up -d

# Clean old images
docker image prune -a -f
```

### Backup Database

```bash
# Manual backup
docker compose -f compose.yml exec postgres \
  pg_dump -U hanzo hanzo | gzip > /backups/hanzo-$(date +%Y%m%d).sql.gz

# Restore
gunzip -c backup.sql.gz | \
  docker compose -f compose.yml exec -T postgres \
  psql -U hanzo hanzo
```

### View Resource Usage

```bash
# Current usage
docker stats --no-stream

# Disk usage
docker system df

# Clean up
docker system prune -a
```

---

## Success Criteria

✅ **Gateway is live:**
- https://gateway.hanzo.ai/health returns 200
- Inference requests work
- Using DigitalOcean + Gradient AI

✅ **Platform is live:**
- https://platform.hanzo.ai loads
- Can create account
- Can get API key

✅ **Load balanced:**
- Multiple gateway replicas running
- Requests distributed evenly

✅ **Secure:**
- HTTPS working (Let's Encrypt)
- Strong passwords set
- Rate limiting active

✅ **Monitored:**
- Logs accessible
- Resource usage visible
- Health checks passing

---

## Summary

**Deployment Time:** 10-15 minutes

**What You Get:**
- Gateway API with DO + Gradient AI
- Platform UI for management
- Automatic HTTPS
- Built-in load balancing (2 gateway replicas)
- PostgreSQL + Redis
- Production-ready security

**Cost:** ~$96/mo (single droplet)

**Next Steps:**
1. Create accounts on Platform UI
2. Get API keys
3. Test inference via Gateway
4. Monitor usage
5. Scale as needed

**Support:**
- Logs: `./deploy.sh logs`
- Status: `./deploy.sh status`
- Restart: `./deploy.sh restart SERVICE`
- Docs: [README.md](README.md)

🎉 **You're live!**
