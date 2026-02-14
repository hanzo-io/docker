# Load Balancing Gateway Instances

## Current Setup (Single Droplet)

**Already has load balancing!** ✅

The `compose.yml` includes:
```yaml
gateway:
  deploy:
    replicas: 2  # Two instances
```

Docker Compose automatically load balances between replicas using internal DNS round-robin. When other services (Caddy, Platform) connect to `gateway:3001`, Docker distributes requests across both instances.

---

## Multi-Droplet Load Balancing Options

When you want gateway instances across **multiple droplets**:

### Option 1: DigitalOcean Load Balancer (Recommended) 🏆

**Pros:**
- ✅ Managed service (no maintenance)
- ✅ Automatic health checks
- ✅ SSL termination
- ✅ Easy to configure
- ✅ DDoS protection included
- ✅ Sticky sessions support

**Cons:**
- 💰 $12/month

**Setup:**

```bash
# 1. Create load balancer
doctl compute load-balancer create \
  --name hanzo-gateway-lb \
  --region sfo3 \
  --forwarding-rules "entry_protocol:https,entry_port:443,target_protocol:http,target_port:3001,certificate_id:YOUR_CERT_ID" \
  --health-check "protocol:http,port:3001,path:/health,check_interval_seconds:10,response_timeout_seconds:5,healthy_threshold:3,unhealthy_threshold:3" \
  --droplet-ids DROPLET1_ID,DROPLET2_ID,DROPLET3_ID

# 2. Update DNS
# gateway.hanzo.ai → LOAD_BALANCER_IP
```

**compose.yml adjustment (on each droplet):**
```yaml
gateway:
  deploy:
    replicas: 1  # One per droplet (LB handles multi-droplet)
  ports:
    - "3001:3001"  # Expose to LB
```

### Option 2: Docker Swarm (Built-in Orchestration)

**Pros:**
- ✅ Built into Docker
- ✅ Automatic load balancing
- ✅ Service discovery
- ✅ Rolling updates
- ✅ Health checks
- ✅ Free

**Cons:**
- 🔧 More complex setup
- 🔧 Need to learn Swarm concepts

**Setup:**

```bash
# 1. Initialize Swarm on first droplet (manager)
ssh root@DROPLET1
docker swarm init --advertise-addr DROPLET1_PRIVATE_IP

# Get join token
docker swarm join-token worker

# 2. Join other droplets (workers)
ssh root@DROPLET2
docker swarm join --token TOKEN DROPLET1_PRIVATE_IP:2377

ssh root@DROPLET3
docker swarm join --token TOKEN DROPLET1_PRIVATE_IP:2377

# 3. Deploy stack (on manager)
docker stack deploy -c compose.yml hanzo
```

**compose.yml for Swarm:**
```yaml
version: "3.8"
services:
  gateway:
    image: hanzoai/gateway:latest
    deploy:
      replicas: 6  # Spread across droplets
      placement:
        max_replicas_per_node: 2
      update_config:
        parallelism: 2
        delay: 10s
    networks:
      - hanzo-overlay

networks:
  hanzo-overlay:
    driver: overlay
    attachable: true
```

Swarm automatically:
- Distributes replicas across nodes
- Load balances incoming requests
- Handles failover
- Maintains replica count

### Option 3: Dedicated Load Balancer Droplet

**Pros:**
- ✅ Full control
- ✅ Can use Caddy/nginx/HAProxy
- ✅ Advanced routing rules
- ✅ Cost-effective for large scale

**Cons:**
- 🔧 Manual setup
- 🔧 You manage updates/monitoring
- 💰 Extra droplet (~$12-24/mo)

**Architecture:**
```
                 Internet
                    ↓
            LB Droplet (Caddy)
               gateway.hanzo.ai
                    ↓
    ┌───────────────┼───────────────┐
    ↓               ↓               ↓
Gateway1         Gateway2        Gateway3
Droplet          Droplet         Droplet
:3001            :3001           :3001
```

**Caddyfile (on LB droplet):**
```caddy
gateway.hanzo.ai {
    reverse_proxy {
        # Backend gateway instances
        to http://10.1.1.1:3001 \
           http://10.1.1.2:3001 \
           http://10.1.1.3:3001
        
        # Health checks
        health_uri /health
        health_interval 10s
        health_timeout 5s
        health_status 200
        
        # Load balancing
        lb_policy round_robin
        lb_try_duration 5s
        lb_try_interval 250ms
        
        # Headers
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
    }
}
```

### Option 4: DNS Round-Robin (Basic)

**Pros:**
- ✅ Free
- ✅ Simple
- ✅ No extra infrastructure

**Cons:**
- ❌ No health checks
- ❌ No session persistence
- ❌ Client-side caching issues
- ❌ Uneven distribution

**Setup:**

Add multiple A records:
```
Type  Name     Value        TTL
A     gateway  DROPLET1_IP  60
A     gateway  DROPLET2_IP  60
A     gateway  DROPLET3_IP  60
```

**Not recommended for production** - use only for testing.

---

## Recommended Architecture

### Small Scale (1-2 droplets)

**Single Droplet** with multiple replicas:
```yaml
gateway:
  deploy:
    replicas: 4-8  # Scale vertically
```

Cost: $96/mo (one droplet)

### Medium Scale (2-5 droplets)

**DigitalOcean Load Balancer** + multiple droplets:
```
DO Load Balancer ($12/mo)
    ↓
┌───┼───┬───┐
↓   ↓   ↓   ↓
D1  D2  D3  D4  (each $96/mo)
```

Cost: $12 + ($96 × 4) = $396/mo

### Large Scale (5+ droplets)

**Docker Swarm** for orchestration:
```
Manager Node(s)
    ↓
Worker Nodes (5-20+)
    ↓
Auto-scaling, self-healing
```

Cost: $96/mo per node

---

## Current Deployment Status

### Single Droplet (Now)

**What you have:**
```
Caddy (port 443)
    ↓
Gateway (2 replicas)  ← Load balanced by Docker
    ↓
Redis + PostgreSQL
```

**Capacity:**
- ~1000 req/sec
- ~10,000 concurrent users
- Already load balanced!

**To scale up on single droplet:**
```bash
docker compose up -d --scale gateway=8
```

### Multi-Droplet (Future)

**When you need it:**
- \> 5000 req/sec
- \> 50,000 concurrent users
- Geographic distribution
- High availability

**Recommended approach:**

1. **Start**: 1 droplet with 4-8 replicas
2. **Grow**: Add DO Load Balancer + 2nd droplet
3. **Scale**: Add more droplets behind LB
4. **Enterprise**: Switch to Docker Swarm or Kubernetes

---

## Quick Setup: Add 2nd Droplet with DO LB

### Step 1: Create 2nd Droplet

```bash
doctl compute droplet create hanzo-gateway-2 \
  --region sfo3 \
  --size s-8vcpu-16gb-amd \
  --image docker-20-04 \
  --ssh-keys $(doctl compute ssh-key list --format ID --no-header | head -1)

# Deploy same stack
ssh root@DROPLET2
cd /opt
git clone https://github.com/hanzoai/platform
cd platform/docker
cp .env.example .env
# ... configure .env
./deploy.sh deploy
```

### Step 2: Create Load Balancer

```bash
# Get droplet IDs
doctl compute droplet list --format ID,Name

# Create LB
doctl compute load-balancer create \
  --name hanzo-lb \
  --region sfo3 \
  --forwarding-rules "entry_protocol:https,entry_port:443,target_protocol:http,target_port:3001,certificate_id:YOUR_CERT" \
  --health-check "protocol:http,port:3001,path:/health" \
  --droplet-ids DROPLET1_ID,DROPLET2_ID

# Get LB IP
doctl compute load-balancer list
```

### Step 3: Update DNS

```
gateway.hanzo.ai → LOAD_BALANCER_IP
```

### Step 4: Expose Gateway Ports

On both droplets, update `compose.yml`:

```yaml
gateway:
  deploy:
    replicas: 2  # 2 per droplet = 4 total
  ports:
    - "3001:3001"  # Expose to LB
```

Redeploy:
```bash
docker compose up -d
```

---

## Monitoring Load Balancing

### Check Distribution

```bash
# View logs from all replicas
docker compose logs gateway | grep "Request received"

# See which replica handled request
curl -v https://gateway.hanzo.ai/health | grep X-Served-By
```

### Metrics

Add to `prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'gateway'
    static_configs:
      - targets:
          - 'droplet1:3001'
          - 'droplet2:3001'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
```

View in Grafana:
- Requests per instance
- Error rate per instance
- Latency per instance

---

## Testing Load Balancing

### Single Droplet

```bash
# Should see requests distributed across replicas
for i in {1..100}; do
  curl -s https://gateway.hanzo.ai/health
done

# Check logs
docker compose logs gateway | grep "health check" | tail -20
```

### Multi-Droplet

```bash
# Load test
apt-get install -y apache2-utils
ab -n 1000 -c 10 https://gateway.hanzo.ai/health

# Check distribution
ssh root@droplet1 "docker compose logs gateway | grep health | wc -l"
ssh root@droplet2 "docker compose logs gateway | grep health | wc -l"
```

---

## Summary

**You already have load balancing** with the current setup! 🎉

```yaml
gateway:
  deploy:
    replicas: 2  # ← This gives you load balancing
```

**When to add more:**

| Scale | Solution | Cost |
|-------|----------|------|
| 0-5k req/s | Single droplet, scale replicas | $96/mo |
| 5-20k req/s | DO Load Balancer + 2-3 droplets | ~$300/mo |
| 20k+ req/s | Docker Swarm or K8s | $1000+/mo |

**Recommendation:** Start with single droplet (you already have LB), add DO Load Balancer when needed.
