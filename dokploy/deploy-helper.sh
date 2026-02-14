#!/bin/bash
# Hanzo Dokploy Deployment Helper Script

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Hanzo/Frappe Dokploy Deployment Helper"
echo "======================================"

# Function to check if .env exists
check_env_file() {
    local server_type=$1
    local env_file="$SCRIPT_DIR/$server_type/.env"
    
    if [ ! -f "$env_file" ]; then
        echo "Creating .env file for $server_type..."
        cp "$SCRIPT_DIR/$server_type/.env.example" "$env_file"
        echo "✅ Created $env_file - Please edit this file with your configuration"
        return 1
    fi
    return 0
}

# Function to validate environment
validate_env() {
    local server_type=$1
    local env_file="$SCRIPT_DIR/$server_type/.env"
    
    # Check for default passwords
    if grep -q "change_this" "$env_file" 2>/dev/null; then
        echo "⚠️  Warning: Default passwords found in $server_type/.env"
        echo "   Please update all 'change_this' values before deployment"
        return 1
    fi
    return 0
}

# Function to generate passwords
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Main menu
show_menu() {
    echo ""
    echo "Select an action:"
    echo "1) Setup environment files"
    echo "2) Generate secure passwords"
    echo "3) Validate configuration"
    echo "4) Show deployment instructions"
    echo "5) Create Docker networks"
    echo "6) Exit"
    echo ""
    read -p "Enter your choice [1-6]: " choice
    
    case $choice in
        1) setup_env_files ;;
        2) generate_passwords ;;
        3) validate_config ;;
        4) show_instructions ;;
        5) create_networks ;;
        6) exit 0 ;;
        *) echo "Invalid choice"; show_menu ;;
    esac
}

# Setup environment files
setup_env_files() {
    echo ""
    echo "Setting up environment files..."
    
    for server in db-server app-server proxy-server; do
        check_env_file "$server"
    done
    
    echo ""
    echo "✅ Environment files are ready. Please edit them before deployment."
    show_menu
}

# Generate secure passwords
generate_passwords() {
    echo ""
    echo "Generated secure passwords:"
    echo "=========================="
    echo "DB_ROOT_PASSWORD=$(generate_password)"
    echo "DB_PASSWORD=$(generate_password)"
    echo "ADMIN_PASSWORD=$(generate_password)"
    echo ""
    echo "Copy these to your .env files"
    show_menu
}

# Validate configuration
validate_config() {
    echo ""
    echo "Validating configuration..."
    
    local all_valid=true
    for server in db-server app-server proxy-server; do
        if ! check_env_file "$server"; then
            all_valid=false
        elif ! validate_env "$server"; then
            all_valid=false
        else
            echo "✅ $server configuration looks good"
        fi
    done
    
    if [ "$all_valid" = true ]; then
        echo ""
        echo "✅ All configurations are valid!"
    else
        echo ""
        echo "❌ Please fix the issues above before deployment"
    fi
    
    show_menu
}

# Show deployment instructions
show_instructions() {
    echo ""
    echo "Deployment Instructions"
    echo "======================="
    echo ""
    echo "1. Database Server (hanzo-db):"
    echo "   - Upload: dokploy/db-server/docker-compose.yml"
    echo "   - Configure: Copy .env file contents"
    echo "   - Deploy and note the internal hostname"
    echo ""
    echo "2. Application Server (hanzo-app):"
    echo "   - Upload: dokploy/app-server/docker-compose.yml"
    echo "   - Configure: Update DB_HOST with database hostname"
    echo "   - Deploy and note the internal hostname"
    echo ""
    echo "3. Proxy Server (hanzo-proxy):"
    echo "   - Upload: dokploy/proxy-server/docker-compose.yml"
    echo "   - Configure: Update BACKEND_HOST with app hostname"
    echo "   - Deploy and configure public access"
    echo ""
    echo "4. Create initial site:"
    echo "   docker exec -it hanzo-backend bash"
    echo "   bench new-site erp.hanzo.ai --db-root-password YOUR_PASSWORD"
    echo ""
    show_menu
}

# Create Docker networks (for local testing)
create_networks() {
    echo ""
    echo "Creating Docker networks for local testing..."
    
    for network in hanzo-db-network hanzo-app-network hanzo-proxy-network; do
        if docker network inspect "$network" >/dev/null 2>&1; then
            echo "✅ Network $network already exists"
        else
            docker network create "$network"
            echo "✅ Created network $network"
        fi
    done
    
    show_menu
}

# Start the script
echo ""
echo "This script helps you prepare for Hanzo deployment on Dokploy"
echo "Make sure you have Docker installed for local testing"

show_menu
