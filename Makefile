# Hanzo Platform - Deployment Makefile
# Quick deployment to DigitalOcean

.PHONY: help deploy deploy-manager add-worker status logs clean

# Default target
help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "🚀 Hanzo Platform - Deployment Commands"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "Quick Deploy:"
	@echo "  make deploy         - Deploy manager node to DigitalOcean (full setup)"
	@echo "  make deploy-fast    - Deploy using existing droplet"
	@echo ""
	@echo "Management:"
	@echo "  make status         - Check cluster status"
	@echo "  make logs           - View service logs"
	@echo "  make scale          - Scale services"
	@echo "  make backup         - Backup database"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean          - Remove stack (keeps droplet)"
	@echo "  make destroy        - Destroy everything (including droplet)"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - doctl installed and configured"
	@echo "  - .env file with required variables"
	@echo "  - SSH key added to DO account"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check prerequisites
check-prereqs:
	@echo "🔍 Checking prerequisites..."
	@command -v doctl >/dev/null 2>&1 || { echo "❌ doctl not found. Install: brew install doctl"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "❌ docker not found. Install Docker Desktop"; exit 1; }
	@test -f .env || { echo "❌ .env file not found. Copy .env.example and configure it."; exit 1; }
	@echo "✅ Prerequisites OK"

# Deploy manager node (full setup)
deploy: check-prereqs
	@./deploy-do.sh deploy

# Check cluster status
status:
	@./deploy-do.sh status

# View logs
logs:
	@./deploy-do.sh logs

# SSH to manager
ssh:
	@./deploy-do.sh ssh

# Destroy everything
destroy:
	@./deploy-do.sh destroy
