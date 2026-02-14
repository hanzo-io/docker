#!/usr/bin/env bash
# Hanzo AI Platform - Production Deployment Script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

check_requirements() {
    log_info "Checking requirements..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available"
        exit 1
    fi
    
    if [ ! -f .env ]; then
        log_error ".env file not found"
        log_info "Copy .env.example to .env and configure it"
        exit 1
    fi
    
    log_info "✓ Requirements met"
}

validate_env() {
    log_info "Validating environment..."
    
    # Source .env
    set -a
    source .env
    set +a
    
    # Required vars
    required_vars=(
        "DOMAIN"
        "ACME_EMAIL"
        "POSTGRES_PASSWORD"
        "NEXTAUTH_SECRET"
        "GRAFANA_PASSWORD"
    )
    
    missing_vars=()
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing required environment variables:"
        printf '  %s\n' "${missing_vars[@]}"
        exit 1
    fi
    
    # Check if using example values
    if [ "$POSTGRES_PASSWORD" = "change-me-in-production" ]; then
        log_error "Please change POSTGRES_PASSWORD in .env"
        exit 1
    fi
    
    if [ "$NEXTAUTH_SECRET" = "change-me-to-random-32-char-string" ]; then
        log_error "Please change NEXTAUTH_SECRET in .env"
        exit 1
    fi
    
    log_info "✓ Environment validated"
}

pull_images() {
    log_info "Pulling Docker images..."
    docker compose -f compose.yml pull --quiet
    log_info "✓ Images pulled"
}

init_database() {
    log_info "Initializing database..."
    docker compose -f compose.yml up -d postgres
    
    # Wait for postgres
    log_info "Waiting for PostgreSQL..."
    for i in {1..30}; do
        if docker compose -f compose.yml exec postgres pg_isready -U hanzo &> /dev/null; then
            log_info "✓ PostgreSQL ready"
            return 0
        fi
        sleep 2
    done
    
    log_error "PostgreSQL failed to start"
    return 1
}

deploy() {
    log_info "Deploying Hanzo AI Platform..."
    
    # Deploy core services
    docker compose -f compose.yml up -d postgres redis gateway platform caddy
    
    log_info "Waiting for services to be healthy..."
    sleep 10
    
    # Check health
    if docker compose -f compose.yml ps | grep -q "unhealthy"; then
        log_warn "Some services are unhealthy"
        docker compose -f compose.yml ps
    else
        log_info "✓ All services healthy"
    fi
}

deploy_monitoring() {
    log_info "Deploying monitoring stack..."
    docker compose -f compose.yml --profile monitoring up -d
    log_info "✓ Monitoring deployed"
    log_info "  Grafana: https://metrics.$DOMAIN"
    log_info "  Prometheus: ssh tunnel to localhost:9090"
}

deploy_inference() {
    log_info "Deploying inference node..."
    docker compose -f compose.yml --profile inference up -d
    log_info "✓ Inference node deployed"
}

show_status() {
    log_info "Service status:"
    docker compose -f compose.yml ps
    
    echo ""
    log_info "URLs:"
    source .env
    echo "  Platform: https://platform.$DOMAIN"
    echo "  Gateway:  https://gateway.$DOMAIN"
    echo "  API:      https://api.$DOMAIN"
    echo ""
    log_info "Logs: docker compose -f docker/compose.yml logs -f"
}

# Main
main() {
    local command="${1:-deploy}"
    
    case "$command" in
        deploy)
            check_requirements
            validate_env
            pull_images
            init_database
            deploy
            show_status
            ;;
        
        monitoring)
            check_requirements
            validate_env
            deploy_monitoring
            ;;
        
        inference)
            check_requirements
            validate_env
            deploy_inference
            ;;
        
        status)
            show_status
            ;;
        
        logs)
            docker compose -f compose.yml logs -f "${@:2}"
            ;;
        
        restart)
            docker compose -f compose.yml restart "${@:2}"
            ;;
        
        stop)
            docker compose -f compose.yml stop
            ;;
        
        down)
            docker compose -f compose.yml down
            ;;
        
        *)
            log_error "Unknown command: $command"
            echo "Usage: $0 {deploy|monitoring|inference|status|logs|restart|stop|down}"
            exit 1
            ;;
    esac
}

main "$@"
