#!/bin/bash
#
# Hanzo Platform - DigitalOcean Deployment Script
# Automates deployment of manager node to DO
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
DROPLET_NAME="hanzo-platform"
DROPLET_REGION="${DROPLET_REGION:-sfo3}"
DROPLET_SIZE="${DROPLET_SIZE:-s-8vcpu-16gb-amd}"
DROPLET_IMAGE="docker-20-04"
STACK_NAME="hanzo"
COMPOSE_FILE="compose.distributed.yml"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${PURPLE}▶️  $1${NC}"
}

# Load environment variables
load_env() {
    if [ -f .env ]; then
        export $(cat .env | grep -v '^#' | xargs)
        log_success "Environment variables loaded"
    else
        log_error ".env file not found"
        log_info "Copy .env.example to .env and configure it"
        exit 1
    fi
}

# Check if droplet exists
droplet_exists() {
    doctl compute droplet list --format Name --no-header 2>/dev/null | grep -q "^${DROPLET_NAME}$"
}

# Get droplet IP
get_droplet_ip() {
    doctl compute droplet list --format Name,PublicIPv4 --no-header 2>/dev/null | \
        grep "^${DROPLET_NAME}" | awk '{print $2}'
}

# Get droplet ID
get_droplet_id() {
    doctl compute droplet list --format Name,ID --no-header 2>/dev/null | \
        grep "^${DROPLET_NAME}" | awk '{print $2}'
}

# Create DO droplet
create_droplet() {
    log_step "Creating DigitalOcean droplet..."

    # Get first SSH key fingerprint
    SSH_KEY=$(doctl compute ssh-key list --format Fingerprint --no-header 2>/dev/null | head -1)

    if [ -z "$SSH_KEY" ]; then
        log_error "No SSH keys found in DO account"
        log_info "Add an SSH key: doctl compute ssh-key create <name> --public-key-file ~/.ssh/id_rsa.pub"
        exit 1
    fi

    log_info "Using SSH key: $SSH_KEY"

    # Create droplet
    doctl compute droplet create "$DROPLET_NAME" \
        --region "$DROPLET_REGION" \
        --size "$DROPLET_SIZE" \
        --image "$DROPLET_IMAGE" \
        --ssh-keys "$SSH_KEY" \
        --tag-names hanzo,manager,production \
        --enable-monitoring \
        --enable-ipv6 \
        --wait

    log_success "Droplet created!"

    # Wait for network
    log_info "Waiting for network to be fully ready..."
    sleep 30
}

# Setup droplet
setup_droplet() {
    local IP=$1

    log_step "Setting up droplet at $IP..."

    # Wait for SSH
    log_info "Waiting for SSH to be ready..."
    for i in {1..30}; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$IP "echo test" >/dev/null 2>&1; then
            break
        fi
        sleep 5
    done

    # Create remote directory
    log_step "Copying deployment files..."
    ssh -o StrictHostKeyChecking=no root@$IP "mkdir -p /opt/hanzo/docker"

    # Copy files
    scp -o StrictHostKeyChecking=no "$COMPOSE_FILE" root@$IP:/opt/hanzo/docker/
    scp -o StrictHostKeyChecking=no "traefik.yml" root@$IP:/opt/hanzo/docker/traefik/dynamic/
    scp -o StrictHostKeyChecking=no ".env" root@$IP:/opt/hanzo/docker/

    log_success "Files copied"

    # Initialize Swarm and deploy
    log_step "Initializing Docker Swarm..."
    ssh -o StrictHostKeyChecking=no root@$IP << 'EOF'
        # Get public IP
        PUBLIC_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)

        # Initialize swarm
        docker swarm init --advertise-addr $PUBLIC_IP

        # Save worker token
        docker swarm join-token worker -q > /opt/hanzo/worker-token.txt
EOF

    log_success "Docker Swarm initialized"

    # Deploy stack
    log_step "Deploying Hanzo Platform stack..."
    ssh -o StrictHostKeyChecking=no root@$IP << 'EOF'
        cd /opt/hanzo/docker

        # Load environment
        export $(cat .env | grep -v '^#' | xargs)

        # Deploy stack
        docker stack deploy -c compose.distributed.yml hanzo

        echo "Waiting for services to start..."
        sleep 15

        # Show status
        docker stack services hanzo
EOF

    log_success "Stack deployed!"
}

# Deploy manager node
deploy_manager() {
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "🚀 Hanzo Platform - Manager Node Deployment"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    load_env

    if droplet_exists; then
        log_warn "Droplet '$DROPLET_NAME' already exists!"
        IP=$(get_droplet_ip)
        log_info "IP: $IP"
        echo ""
        read -p "Deploy to existing droplet? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled. Use './deploy-do.sh destroy' to remove existing droplet"
            exit 1
        fi
    else
        create_droplet
    fi

    IP=$(get_droplet_ip)
    log_success "Droplet IP: $IP"

    setup_droplet "$IP"

    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "🎉 Deployment Complete!"
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "Manager Node: $IP"
    log_info "SSH: ssh root@$IP"
    echo ""
    log_info "Next Steps:"
    log_info "1. Update DNS records:"
    log_info "   platform.$DOMAIN → $IP"
    log_info "   api.$DOMAIN → $IP"
    echo ""
    log_info "2. Access Platform UI (wait 2-3 min for SSL certs):"
    log_info "   https://platform.$DOMAIN"
    echo ""
    log_info "3. Add worker nodes via UI:"
    log_info "   Settings → Cluster → Node Orchestration"
    echo ""
    log_info "Commands:"
    log_info "  Status: ./deploy-do.sh status"
    log_info "  Logs: ./deploy-do.sh logs"
    log_info "  SSH: ./deploy-do.sh ssh"
    echo ""
    log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# Show status
show_status() {
    if ! droplet_exists; then
        log_error "Droplet not found"
        exit 1
    fi

    IP=$(get_droplet_ip)

    log_info "Droplet IP: $IP"
    echo ""
    log_info "Cluster Nodes:"
    ssh -o StrictHostKeyChecking=no root@$IP "docker node ls"

    echo ""
    log_info "Stack Services:"
    ssh -o StrictHostKeyChecking=no root@$IP "docker stack services hanzo"

    echo ""
    log_info "Service Tasks:"
    ssh -o StrictHostKeyChecking=no root@$IP "docker stack ps hanzo"
}

# Show logs
show_logs() {
    if ! droplet_exists; then
        log_error "Droplet not found"
        exit 1
    fi

    IP=$(get_droplet_ip)
    SERVICE=${1:-platform}

    log_info "Showing logs for hanzo_$SERVICE..."
    ssh -o StrictHostKeyChecking=no root@$IP "docker service logs -f --tail 100 hanzo_$SERVICE"
}

# SSH to manager
ssh_to_manager() {
    if ! droplet_exists; then
        log_error "Droplet not found"
        exit 1
    fi

    IP=$(get_droplet_ip)
    log_info "Connecting to $IP..."
    ssh -o StrictHostKeyChecking=no root@$IP
}

# Destroy droplet
destroy_all() {
    if ! droplet_exists; then
        log_error "Droplet not found"
        exit 1
    fi

    DROPLET_ID=$(get_droplet_id)

    echo ""
    log_warn "⚠️  WARNING: This will DELETE the droplet and ALL DATA!"
    echo ""
    read -p "Type 'DELETE' to confirm: " confirm

    if [ "$confirm" != "DELETE" ]; then
        log_info "Cancelled"
        exit 0
    fi

    log_warn "Destroying droplet $DROPLET_NAME (ID: $DROPLET_ID)..."
    doctl compute droplet delete "$DROPLET_ID" --force

    log_success "Droplet destroyed"
}

# Main
case "${1:-deploy}" in
    deploy)
        deploy_manager
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "${2:-platform}"
        ;;
    ssh)
        ssh_to_manager
        ;;
    destroy)
        destroy_all
        ;;
    help|*)
        echo "Usage: $0 {deploy|status|logs|ssh|destroy}"
        echo ""
        echo "Commands:"
        echo "  deploy   - Deploy manager node to DigitalOcean"
        echo "  status   - Show cluster status"
        echo "  logs     - View service logs (default: platform)"
        echo "  ssh      - SSH to manager node"
        echo "  destroy  - Destroy droplet (WARNING: deletes all data)"
        echo ""
        exit 0
        ;;
esac
