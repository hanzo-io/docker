# 🚀 Deploy platform.hanzo.ai NOW

## What We're Deploying

### Core Services (NO GPU Required)

1. **Gateway** (`hanzoai/gateway:latest`)
   - Free tier inference proxy
   - Routes to external APIs (OpenAI, Anthropic, DeepSeek, etc.)
   - Built-in rate limiting
   - **Status: ✅ LIVE on Docker Hub**

2. **Platform** (`hanzoai/platform:latest`)
   - Management UI v4.0.6
   - Application & database management
   - User dashboard
   - **Status: ✅ LIVE on Docker Hub**

3. **Supporting Services**
   - PostgreSQL 16 - Database
   - Redis 7 - Cache & rate limiting
   - Caddy 2 - Automatic HTTPS

### NOT Deploying (Requires GPU)

- ❌ Hanzo-Node - Local inference (requires NVIDIA GPU)
- Gateway works WITHOUT this by using external APIs

---

## 5-Minute Deployment

### Prerequisites

- DigitalOcean droplet (or any Docker host)
- Domain with DNS configured
- 8GB+ RAM, 4+ cores

### Step 1: Create Droplet (2 min)

```bash
# Using doctl
doctl compute droplet create hanzo-platform \
  --region sfo3 \
  --size s-8vcpu-16gb-amd \
  --image docker-20-04 \
  --ssh-keys $(doctl compute ssh-key list --format ID --no-header | head -1) \
  --wait

# Get IP
DROPLET_IP=$(doctl compute droplet list --format Name,PublicIPv4 --no-header | grep hanzo-platform | awk '{print $2}')
echo "Droplet IP: $DROPLET_IP"
```

**Or manually:**
1. Go to https://cloud.digitalocean.com/droplets/new
2. Choose: Docker on Ubuntu 20.04
3. Size: 8GB RAM / 4 CPUs ($48/mo) or 16GB / 8 CPUs ($96/mo)
4. Region: San Francisco (sfo3)
5. Create droplet

### Step 2: Configure DNS (1 min)

Add A records pointing to your droplet IP:

```
Type  Name      Value        TTL
A     platform  DROPLET_IP   3600
A     gateway   DROPLET_IP   3600
A     api       DROPLET_IP   3600
```

**Verify:**
```bash
dig platform.hanzo.ai +short
# Should show: DROPLET_IP
```

### Step 3: SSH and Deploy (2 min)

```bash
# SSH to droplet
ssh root@$DROPLET_IP

# Clone repo
cd /opt
git clone https://github.com/hanzoai/platform
cd platform/docker

# Configure environment
cp .env.example .env

# Generate secure passwords
sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -base64 32)/" .env
sed -i "s/NEXTAUTH_SECRET=.*/NEXTAUTH_SECRET=$(openssl rand -base64 32)/" .env
sed -i "s/GRAFANA_PASSWORD=.*/GRAFANA_PASSWORD=$(openssl rand -base64 16)/" .env

# Set domain
sed -i "s/DOMAIN=.*/DOMAIN=hanzo.ai/" .env
sed -i "s/ACME_EMAIL=.*/ACME_EMAIL=admin@hanzo.ai/" .env

# Optional: Add API keys for providers
# vim .env
# OPENAI_API_KEY=sk-...
# ANTHROPIC_API_KEY=sk-ant-...
# DEEPSEEK_API_KEY=sk-...

# Deploy!
./deploy.sh deploy
```

### Step 4: Verify (30 sec)

```bash
# Check status
./deploy.sh status

# Test endpoints
curl https://platform.hanzo.ai/api/health
curl https://gateway.hanzo.ai/health

# View logs
./deploy.sh logs
```

---

## What Gets Deployed

### Services

```
┌─────────────────────────────────────────┐
│  Internet                               │
│    ↓                                    │
│  Caddy :443 (Auto HTTPS)                │
│    ↓                                    │
│  ┌─────────────┬─────────────┐         │
│  │             │             │          │
│  Platform    Gateway      PostgreSQL   │
│  :3000       :3001        :5432        │
│  (UI)        (API)        (Database)   │
│              ↓                          │
│            Redis :6379                  │
│            (Cache)                      │
└─────────────────────────────────────────┘
```

### URLs

- **Platform UI**: https://platform.hanzo.ai
- **Gateway API**: https://gateway.hanzo.ai  
- **API Alias**: https://api.hanzo.ai → gateway

### Resource Usage

```
Service      Replicas  CPU    RAM    Total RAM
─────────────────────────────────────────────
PostgreSQL   1         2      4GB    4GB
Redis        1         1      2GB    2GB
Gateway      2         1      1GB    2GB
Platform     2         2      2GB    4GB
Caddy        1         1      512MB  512MB
─────────────────────────────────────────────
Total                         ~12.5GB
Available for OS/buffer       ~3.5GB
```

---

## After Deployment

### Test the Gateway API

```bash
# Free tier endpoint
curl -X POST https://gateway.hanzo.ai/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-api-key" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [
      {"role": "user", "content": "Hello from Hanzo!"}
    ]
  }'
```

### Access Platform UI

1. Open https://platform.hanzo.ai
2. Create account
3. Get API key
4. Use with gateway API

### View Metrics (Optional)

```bash
# Deploy monitoring
./deploy.sh monitoring

# Access Grafana
open https://metrics.hanzo.ai
# Username: admin
# Password: (from .env GRAFANA_PASSWORD)
```

---

## Scale Up

### Horizontal Scaling

```bash
# More gateway instances (handle more requests)
docker compose up -d --scale gateway=5

# More platform instances
docker compose up -d --scale platform=3

# Verify
docker compose ps
```

### Add API Keys

```bash
# Edit .env
vim .env

# Add provider keys
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
DEEPSEEK_API_KEY=sk-...
DIGITALOCEAN_API_KEY=dop_v1_...

# Restart gateway
docker compose restart gateway
```

---

## Future: Add GPU Inference

When you have a GPU server available:

### Hardware Requirements

- NVIDIA GPU (RTX 3090, A100, etc.)
- 16GB+ VRAM
- CUDA 11.8+
- 16GB+ system RAM

### Deploy Hanzo-Node

```bash
# Set environment
echo "ENABLE_LOCAL_NODE=true" >> .env

# Deploy with inference profile
docker compose --profile inference up -d

# Verify
curl http://localhost:8000/health
```

### GPU Server Options

**DigitalOcean GPU Droplet:**
- g-8vcpu-32gb: $168/mo (Tesla P100)
- g-16vcpu-64gb: $336/mo (Tesla V100)

**Other Options:**
- Lambda Labs - GPU cloud
- Vast.ai - Spot GPU instances
- Your own hardware

---

## Troubleshooting

### Gateway not responding?

```bash
# Check logs
docker compose logs gateway

# Restart
docker compose restart gateway

# Check health
curl http://localhost:3001/health
```

### Platform UI not loading?

```bash
# Check logs
docker compose logs platform

# Check Caddy
docker compose logs caddy

# Verify DNS
dig platform.hanzo.ai +short
```

### SSL certificate issues?

```bash
# Check Caddy logs
docker compose logs caddy

# Force renewal
docker compose restart caddy

# Wait 2 minutes for Let's Encrypt
sleep 120
curl -I https://platform.hanzo.ai
```

### Database connection errors?

```bash
# Check PostgreSQL
docker compose exec postgres pg_isready -U hanzo

# Check connections
docker compose exec postgres psql -U hanzo -c "SELECT count(*) FROM pg_stat_activity;"

# Restart
docker compose restart postgres
```

---

## Cost Breakdown

### Minimum Production Setup

```
Service                          Cost/mo
─────────────────────────────────────────
DigitalOcean Droplet
  s-8vcpu-16gb-amd              $96.00
Domain (if buying new)          $12.00
Backups (optional)              $9.60
─────────────────────────────────────────
Total (without GPU)             $117.60

With external API usage:
  OpenAI API                    Pay per use
  Anthropic API                 Pay per use
  DeepSeek API                  Pay per use
```

### With GPU (Future)

```
Additional GPU Droplet          +$168-336/mo
Or Lambda Labs GPU              +$100-200/mo
Or Your own hardware            One-time cost
```

---

## Support

**Documentation:**
- Full guide: [README.md](README.md)
- Complete guide: [PLATFORM_DEPLOYMENT.md](PLATFORM_DEPLOYMENT.md)
- Status: [DEPLOYMENT_READY.md](DEPLOYMENT_READY.md)

**Issues:**
- GitHub: https://github.com/hanzoai/platform/issues
- Discord: https://discord.gg/hanzoai
- Email: support@hanzo.ai

---

## Summary

✅ **Gateway + Platform ready to deploy NOW**
✅ **No GPU required**
✅ **Free tier works with external APIs**
✅ **5-10 minute deployment**
✅ **~$96-120/month**

⏳ **GPU inference is optional future enhancement**

```bash
# Deploy command
cd /opt/platform/docker && ./deploy.sh deploy
```

🚀 **Let's go live!**
