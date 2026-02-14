# Hanzo Platform - Node Orchestration Guide

## 🚀 Decentralized Cloud Infrastructure

This guide covers deploying and managing a decentralized network of DigitalOcean droplets as hanzo-node workers using the Hanzo Platform UI.

---

## Overview

**Architecture:**
- **Manager Node**: Runs Platform UI + Gateway + PostgreSQL + Redis
- **Worker Nodes**: Auto-deployed DO droplets running hanzo-node for inference
- **Orchestration**: Docker Swarm with automatic node joining
- **Standard Size**: 8 vCPU, 16GB RAM AMD droplets ($96/month each)

**Key Features:**
✅ One-click node creation from Platform UI
✅ Automatic Docker Swarm joining
✅ Pre-configured hanzo-node images
✅ k3s OR Docker (configurable)
✅ Load balancing across nodes
✅ Horizontal scaling via UI

---

## Quick Start (5 minutes)

### 1. Deploy Manager Node

```bash
# Create manager droplet
doctl compute droplet create hanzo-manager \
  --region sfo3 \
  --size s-8vcpu-16gb-amd \
  --image docker-20-04 \
  --ssh-keys YOUR_SSH_KEY \
  --wait

# SSH to manager
ssh root@MANAGER_IP

# Initialize Swarm
docker swarm init --advertise-addr MANAGER_IP

# Set environment variables
export DIGITALOCEAN_API_KEY="your_do_api_key"
export POSTGRES_PASSWORD="$(openssl rand -base64 32)"
export REDIS_PASSWORD="$(openssl rand -base64 32)"
export NEXTAUTH_SECRET="$(openssl rand -hex 32)"
export DEEPSEEK_API_KEY="your_deepseek_key"
export DOMAIN="hanzo.ai"
export ACME_EMAIL="admin@hanzo.ai"

# Deploy stack
cd /opt
git clone https://github.com/hanzoai/universe hanzo
cd hanzo/docker
docker stack deploy -c compose.distributed.yml hanzo
```

### 2. Access Platform UI

Navigate to: `https://platform.hanzo.ai`

- Register first user (becomes admin)
- Go to **Settings → Cluster → Node Orchestration**

### 3. Add Worker Nodes

In the Platform UI:

1. Click **"Add Node"**
2. Configure:
   - Region: `sfo3` (or nearest)
   - Type: `Inference`
   - GPU: `false` (CPU) or `true` (+$300/mo)
   - Auto-join Swarm: `true`
3. Click **"Create Node"**

**Result:** Node provisions in 2-3 minutes and auto-joins swarm!

---

## Node Configuration

### Standard Node (Inference)

- **vCPU**: 8 cores
- **RAM**: 16GB
- **Disk**: 320GB SSD
- **Cost**: $96/month
- **Use**: LLM inference, general compute

### GPU Node (Optional)

- **vCPU**: 8 cores
- **RAM**: 32GB
- **GPU**: 1x NVIDIA GPU
- **Cost**: ~$400/month
- **Use**: Heavy inference, training

### Available Regions

- `sfo3` - San Francisco 3 (US West)
- `nyc3` - New York 3 (US East)
- `ams3` - Amsterdam 3 (EU)
- `sgp1` - Singapore 1 (Asia)
- `lon1` - London 1 (EU)
- `fra1` - Frankfurt 1 (EU)

---

## Architecture Details

### Manager Node Services

```yaml
Manager (8 vCPU, 16GB RAM):
  - Caddy (HTTPS reverse proxy)
  - Platform UI (management interface)
  - Gateway (inference proxy, 2 replicas)
  - PostgreSQL 16 (database)
  - Redis 7 (cache & rate limiting)
```

### Worker Node Setup (Automated)

When you create a node via UI, it:

1. **Provisions DO droplet** (2-3 min)
   - Docker pre-installed
   - Firewall configured
   - Monitoring enabled

2. **Runs cloud-init script:**
   ```bash
   # Install k3s (optional, commented by default)
   # curl -sfL https://get.k3s.io | sh -

   # Pull hanzo-node image
   docker pull hanzoai/node:latest

   # Join Docker Swarm
   docker swarm join --token WORKER_TOKEN MANAGER_IP:2377

   # Start hanzo-node
   docker run -d --name hanzo-node \
     --network host \
     -e SWARM_MODE=true \
     -v /var/run/docker.sock:/var/run/docker.sock \
     hanzoai/node:latest
   ```

3. **Labels node in swarm:**
   - `type=inference`
   - `gpu=true` (if GPU enabled)

4. **Reports ready** to platform API

---

## Scaling

### Horizontal Scaling

**Via UI:**
1. Go to **Cluster → Node Orchestration**
2. View active nodes
3. Click **"Add Node"** for more capacity
4. Services auto-balance across nodes

**Via CLI:**
```bash
# Scale hanzo-node service to 5 replicas
docker service scale hanzo_hanzo-node=5

# Check distribution
docker service ps hanzo_hanzo-node
```

### Vertical Scaling

**Resize a node:**
1. UI: Node → Actions → Resize
2. Select new size
3. Node powers off, resizes, restarts (~5 min)

---

## Monitoring

### Cluster Stats (Platform UI)

Dashboard shows:
- Total nodes
- Active nodes
- Worker/Manager count
- Node health status

### Prometheus + Grafana (Optional)

Enable monitoring profile:

```bash
docker stack deploy -c compose.distributed.yml hanzo \
  --with-registry-auth \
  --compose-profile monitoring
```

Access:
- **Prometheus**: `https://metrics.hanzo.ai`
- **Grafana**: `https://grafana.hanzo.ai`

---

## Node Management

### View Nodes

**UI:** Settings → Cluster → Node Orchestration

**CLI:**
```bash
# Swarm nodes
docker node ls

# DO droplets
doctl compute droplet list --tag-name hanzo-node

# Service distribution
docker service ps hanzo_hanzo-node
```

### Delete Node

**UI:** Node → Actions → Delete

**CLI:**
```bash
# Drain node first
docker node update --availability drain NODE_ID

# Remove from swarm
docker node rm NODE_ID --force

# Delete droplet
doctl compute droplet delete DROPLET_ID
```

### Node Health

Nodes report health every 30s. If unhealthy:
1. Check node logs: `docker service logs hanzo_hanzo-node`
2. SSH to node: `ssh root@NODE_IP`
3. Restart service: `docker service update --force hanzo_hanzo-node`

---

## Cost Optimization

### Starting Small (1 Manager only)

**Cost:** $96/month
- Manager handles everything
- No local inference (uses DO AI API)
- Good for: Testing, low traffic

### Production (Manager + 2 Workers)

**Cost:** $288/month ($96 × 3)
- Load balanced inference
- Redundancy
- Good for: Production workloads

### High Performance (Manager + 5 GPU Workers)

**Cost:** $96 + ($400 × 5) = $2,096/month
- Heavy inference capacity
- GPU acceleration
- Good for: High-volume AI workloads

**Tips:**
- Start with 0-1 workers
- Scale up during high demand
- Scale down at night (auto-scaling coming soon)

---

## Troubleshooting

### Node Won't Join Swarm

```bash
# On manager, check token
docker swarm join-token worker

# On worker, manually join
docker swarm join --token TOKEN MANAGER_IP:2377
```

### Node Shows "Provisioning" Forever

1. Check DO dashboard for droplet status
2. SSH to node and check cloud-init:
   ```bash
   cloud-init status
   journalctl -u cloud-init-local
   ```

### Service Won't Deploy to Workers

```bash
# Check node constraints
docker service inspect hanzo_hanzo-node

# Verify node labels
docker node inspect NODE_ID | grep Labels

# Add label manually
docker node update --label-add type=inference NODE_ID
```

### High Memory Usage

```bash
# Check resource usage
docker stats

# Adjust service limits in compose.distributed.yml:
resources:
  limits:
    memory: 12G  # Reduce if needed
```

---

## Security

### Firewall Rules (Auto-configured)

```bash
Inbound:
  - 22/tcp   (SSH)
  - 80/tcp   (HTTP)
  - 443/tcp  (HTTPS)
  - 2377/tcp (Swarm manager)
  - 7946/tcp (Swarm communication)
  - 4789/udp (Overlay network)

Outbound:
  - All allowed
```

### Secret Management

Secrets stored as Docker secrets (encrypted at rest):
- `DIGITALOCEAN_API_KEY`
- `POSTGRES_PASSWORD`
- `REDIS_PASSWORD`
- `NEXTAUTH_SECRET`

### Node Access

- Manager: SSH + Platform UI
- Workers: Internal swarm network only
- No direct public access to workers

---

## Next Steps

1. ✅ Deploy manager node
2. ✅ Access Platform UI
3. ✅ Create first worker node via UI
4. 🔨 Scale to 2-3 workers
5. 🔨 Enable monitoring (optional)
6. 🔨 Set up automated backups

---

## API Reference

### Create Node

```typescript
api.nodeOrchestration.createNode.mutate({
  name: "hanzo-node-1",
  region: "sfo3",
  nodeType: "inference",
  enableGPU: false,
  autoJoinSwarm: true
})
```

### List Nodes

```typescript
const { data } = api.nodeOrchestration.listNodes.useQuery();
// Returns: { nodes: [], total: 0 }
```

### Delete Node

```typescript
api.nodeOrchestration.deleteNode.mutate({
  dropletId: 12345
})
```

---

## Support

- **Documentation**: `/docker/NODE_ORCHESTRATION.md`
- **Platform UI**: Settings → Cluster
- **Issues**: https://github.com/hanzoai/platform/issues

**Ready to scale?** Create your first node via the Platform UI! 🚀
