# Multi-Droplet Load Balancing - Correct Setup

## Current Setup (Single Droplet Only)

**What you have NOW:**

```
Single DigitalOcean Droplet ($96/mo)
┌─────────────────────────────────────────┐
│  Docker Compose creates 2 containers:   │
│                                         │
│    gateway-1 (container)                │
│    gateway-2 (container)                │
│                                         │
│  Docker internal DNS load balances      │
│  between these 2 containers             │
└─────────────────────────────────────────┘

Capacity: ~1-2k req/sec
```

**This is NOT multi-droplet!** It's just multiple containers on one machine.

---

## Multi-Droplet Options

You're right - to use multiple droplets, you need orchestration!

### Option 1: DigitalOcean Load Balancer (Recommended) ✅

**Architecture:**
```
                     Internet
                        ↓
         ╔══════════════════════════════╗
         ║  DigitalOcean Load Balancer ║  ← External managed LB
         ║         ($12/mo)             ║
         ╚═══════════════┬══════════════╝
                         ↓
         ┌───────────────┼───────────────┐
         ↓               ↓               ↓
    Droplet 1        Droplet 2       Droplet 3
    ($96/mo)         ($96/mo)        ($96/mo)
    ┌─────────┐      ┌─────────┐     ┌─────────┐
    │Gateway×2│      │Gateway×2│     │Gateway×2│
    │Platform │      │Platform │     │Platform │
    │Postgres │      │Postgres*│     │Postgres*│
    │Redis    │      │Redis*   │     │Redis*   │
    └─────────┘      └─────────┘     └─────────┘
    
    *Replica or read-only

Total: $300/mo (LB + 3 droplets)
Capacity: ~6-10k req/sec
```

**How it works:**
- Each droplet runs **independently**
- They do NOT know about each other
- DO Load Balancer distributes traffic
- No Docker Swarm/K8s needed

**Setup:**

```bash
# 1. Create 3 identical droplets
for i in 1 2 3; do
  doctl compute droplet create hanzo-gateway-$i \
    --region sfo3 \
    --size s-8vcpu-16gb-amd \
    --image docker-20-04 \
    --wait
done

# 2. Deploy stack on each droplet
for ip in $DROPLET1_IP $DROPLET2_IP $DROPLET3_IP; do
  ssh root@$ip "
    cd /opt
    git clone https://github.com/hanzoai/platform
    cd platform/docker
    cp .env.example .env
    # Configure .env
    ./deploy.sh deploy
  "
done

# 3. Create Load Balancer
doctl compute load-balancer create \
  --name hanzo-gateway-lb \
  --region sfo3 \
  --forwarding-rules \
    "entry_protocol:https,entry_port:443,target_protocol:http,target_port:443,certificate_id:YOUR_CERT" \
  --health-check \
    "protocol:http,port:443,path:/health" \
  --droplet-ids $DROPLET1_ID,$DROPLET2_ID,$DROPLET3_ID

# 4. Point DNS to Load Balancer IP
# gateway.hanzo.ai → LOAD_BALANCER_IP
```

**Pros:**
- ✅ Simple - droplets are independent
- ✅ Managed by DigitalOcean
- ✅ Automatic health checks
- ✅ Easy to add/remove droplets
- ✅ No orchestration needed

**Cons:**
- 💰 $12/mo for LB
- 🔧 Need to deploy to each droplet separately
- 🔧 No automatic container distribution

---

### Option 2: Docker Swarm (Droplets Become Nodes) ✅

**Architecture:**
```
                     Internet
                        ↓
                  Swarm Ingress
                  (Built-in LB)
                        ↓
         ┌──────────────┼──────────────┐
         ↓              ↓              ↓
    Manager Node   Worker Node    Worker Node
    (Droplet 1)    (Droplet 2)    (Droplet 3)
    ┌─────────┐    ┌─────────┐    ┌─────────┐
    │         │    │         │    │         │
    │ Swarm automatically distributes     │
    │ gateway containers across all nodes │
    │                                      │
    └──────────────────────────────────────┘

Total: $288/mo (3 droplets)
Capacity: ~6-10k req/sec
```

**How it works:**
- Droplets join a Swarm cluster
- They become "nodes" in the cluster
- Swarm distributes containers across nodes
- Built-in load balancing and service discovery
- One deployment, runs everywhere

**Setup:**

```bash
# 1. Create 3 droplets (same as before)

# 2. Initialize Swarm on first droplet (manager)
ssh root@$DROPLET1_IP
docker swarm init --advertise-addr $DROPLET1_PRIVATE_IP

# Save the join token
WORKER_TOKEN=$(docker swarm join-token worker -q)

# 3. Join other droplets as workers
ssh root@$DROPLET2_IP
docker swarm join --token $WORKER_TOKEN $DROPLET1_PRIVATE_IP:2377

ssh root@$DROPLET3_IP
docker swarm join --token $WORKER_TOKEN $DROPLET1_PRIVATE_IP:2377

# 4. Deploy stack (from manager node)
ssh root@$DROPLET1_IP
cd /opt/platform/docker
docker stack deploy -c compose.yml hanzo

# Swarm automatically distributes containers across all 3 nodes!
```

**compose.yml for Swarm:**
```yaml
version: "3.8"

services:
  gateway:
    image: hanzoai/gateway:latest
    deploy:
      replicas: 6  # Swarm distributes across nodes
      placement:
        max_replicas_per_node: 2
      update_config:
        parallelism: 2
        delay: 10s
    networks:
      - hanzo-overlay
    environment:
      - DIGITALOCEAN_API_KEY=${DIGITALOCEAN_API_KEY}

networks:
  hanzo-overlay:
    driver: overlay
    attachable: true
```

**Pros:**
- ✅ Built into Docker (free)
- ✅ Automatic container distribution
- ✅ Built-in load balancing
- ✅ Service discovery
- ✅ Rolling updates
- ✅ Self-healing
- ✅ One deployment command

**Cons:**
- 🔧 More complex than standalone
- 🔧 Need to learn Swarm concepts
- 🔧 Manager node is single point of failure (unless you add more managers)

---

### Option 3: Kubernetes (Most Complex)

**For 50+ droplets or enterprise scale**

Not recommended unless you need:
- Auto-scaling
- Complex orchestration
- Multi-region
- 1000+ containers

---

## Which Should You Use?

### Start: Single Droplet (Current)
```
Cost: $96/mo
Capacity: 1-2k req/sec
Setup: ✅ Already done!
```

Just scale replicas:
```bash
docker compose up -d --scale gateway=8
```

### Grow: Add DO Load Balancer
```
Cost: $300/mo (LB + 3 droplets)
Capacity: 6-10k req/sec
Setup: 30 min
Complexity: Low
```

When you need:
- More than 2-5k req/sec
- High availability
- Multiple regions

### Scale: Docker Swarm
```
Cost: $288-600/mo (3-6 droplets)
Capacity: 10-50k req/sec
Setup: 1 hour
Complexity: Medium
```

When you need:
- Automatic container distribution
- Easy scaling (add nodes)
- Built-in orchestration
- No external LB costs

---

## Recommendation

**For platform.hanzo.ai + gateway.hanzo.ai:**

### Phase 1: Single Droplet (NOW) ✅
```bash
cd /opt/platform/docker
./deploy.sh deploy

# Scale up as needed
docker compose up -d --scale gateway=8
```

**Good for:** Getting started, 0-5k req/sec

### Phase 2: Add DO Load Balancer (When Needed)

**When:** Traffic exceeds 5k req/sec

```bash
# Create 2 more droplets
# Set up DO Load Balancer
# Point DNS to LB
```

**Good for:** 5-20k req/sec, HA

### Phase 3: Docker Swarm (If Needed)

**When:** Need more than 5 droplets, want easier management

```bash
# Convert droplets to Swarm nodes
# Deploy with docker stack
# Add/remove nodes as needed
```

**Good for:** 20k+ req/sec, enterprise

---

## Current Action Plan

**Deploy NOW (Single Droplet):**

```bash
# This gives you load balancing within one droplet
cd /opt/platform/docker
./deploy.sh deploy
```

**You get:**
- ✅ Gateway (2 replicas, load balanced)
- ✅ Platform (2 replicas, load balanced)
- ✅ ~1-2k req/sec capacity
- ✅ Ready in 15 minutes

**Add droplets LATER when you need more capacity.**

---

## Key Takeaway

**Current setup (single droplet):**
- ✅ Load balancing works WITHIN the droplet
- ✅ Docker internal DNS balances between containers
- ✅ Good for 1-2k req/sec
- ✅ No nodes/orchestration needed

**Multi-droplet (future):**
- ❌ Current setup does NOT work across droplets
- ✅ Need either DO Load Balancer OR Docker Swarm
- ✅ Use when you need > 5k req/sec

**You're correct** - multiple droplets need orchestration (nodes). But start with single droplet - it already has load balancing!
