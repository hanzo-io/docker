# Dokploy Deployment Strategy for Hanzo/Frappe

## Overview

This document outlines how to deploy the three-server Frappe/Hanzo architecture using Dokploy, with each server type as a separate service accessible via Cloudflare Tunnels.

## Architecture Mapping

### 1. Database Server (M Server)

**Dokploy Application Name**: `hanzo-db`

```yaml
# docker-compose.yml for M server
services:
  mariadb:
    image: mariadb:10.11
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
      MYSQL_DATABASE: ${DB_NAME:-frappe}
      MYSQL_USER: ${DB_USER:-frappe}
      MYSQL_PASSWORD: ${DB_PASSWORD}
    volumes:
      - mariadb_data:/var/lib/mysql
    ports:
      - "3306:3306"
    restart: unless-stopped
    command: 
      - --innodb_buffer_pool_size=512M
      - --max_connections=500
      
  redis-cache:
    image: redis:7-alpine
    volumes:
      - redis_cache_data:/data
    ports:
      - "6379:6379"
    restart: unless-stopped
    
  redis-queue:
    image: redis:7-alpine
    volumes:
      - redis_queue_data:/data
    ports:
      - "6380:6379"
    restart: unless-stopped

volumes:
  mariadb_data:
  redis_cache_data:
  redis_queue_data:
```

### 2. Application Server (F Server)

**Dokploy Application Name**: `hanzo-app`

```yaml
# docker-compose.yml for F server
services:
  configurator:
    image: ${HANZO_IMAGE:-frappe/erpnext}:${VERSION:-latest}
    platform: linux/amd64
    entrypoint: ["bash", "-c"]
    command:
      - >
        bench set-config -g db_host ${DB_HOST};
        bench set-config -gp db_port ${DB_PORT:-3306};
        bench set-config -g redis_cache "redis://${REDIS_HOST}:6379";
        bench set-config -g redis_queue "redis://${REDIS_HOST}:6380";
        bench set-config -gp socketio_port 9000;
    environment:
      DB_HOST: ${DB_HOST}
      DB_PORT: ${DB_PORT:-3306}
      REDIS_HOST: ${REDIS_HOST}
    volumes:
      - sites:/home/frappe/frappe-bench/sites
    restart: on-failure

  backend:
    image: ${HANZO_IMAGE:-frappe/erpnext}:${VERSION:-latest}
    platform: linux/amd64
    depends_on:
      configurator:
        condition: service_completed_successfully
    volumes:
      - sites:/home/frappe/frappe-bench/sites
    ports:
      - "8000:8000"
    restart: unless-stopped

  websocket:
    image: ${HANZO_IMAGE:-frappe/erpnext}:${VERSION:-latest}
    platform: linux/amd64
    command: node /home/frappe/frappe-bench/apps/frappe/socketio.js
    depends_on:
      configurator:
        condition: service_completed_successfully
    volumes:
      - sites:/home/frappe/frappe-bench/sites
    ports:
      - "9000:9000"
    restart: unless-stopped

  queue-short:
    image: ${HANZO_IMAGE:-frappe/erpnext}:${VERSION:-latest}
    platform: linux/amd64
    command: bench worker --queue short,default
    depends_on:
      configurator:
        condition: service_completed_successfully
    volumes:
      - sites:/home/frappe/frappe-bench/sites
    restart: unless-stopped

  queue-long:
    image: ${HANZO_IMAGE:-frappe/erpnext}:${VERSION:-latest}
    platform: linux/amd64
    command: bench worker --queue long,default,short
    depends_on:
      configurator:
        condition: service_completed_successfully
    volumes:
      - sites:/home/frappe/frappe-bench/sites
    restart: unless-stopped

  scheduler:
    image: ${HANZO_IMAGE:-frappe/erpnext}:${VERSION:-latest}
    platform: linux/amd64
    command: bench schedule
    depends_on:
      configurator:
        condition: service_completed_successfully
    volumes:
      - sites:/home/frappe/frappe-bench/sites
    restart: unless-stopped

volumes:
  sites:
```

### 3. Proxy Server (N Server)

**Dokploy Application Name**: `hanzo-proxy`

```yaml
# docker-compose.yml for N server
services:
  nginx:
    image: ${HANZO_IMAGE:-frappe/erpnext}:${VERSION:-latest}
    platform: linux/amd64
    command: nginx-entrypoint.sh
    environment:
      BACKEND: ${APP_SERVER_HOST}:8000
      SOCKETIO: ${APP_SERVER_HOST}:9000
      FRAPPE_SITE_NAME_HEADER: ${FRAPPE_SITE_NAME_HEADER:-$host}
      UPSTREAM_REAL_IP_ADDRESS: ${UPSTREAM_REAL_IP_ADDRESS:-127.0.0.1}
      UPSTREAM_REAL_IP_HEADER: ${UPSTREAM_REAL_IP_HEADER:-X-Forwarded-For}
      UPSTREAM_REAL_IP_RECURSIVE: ${UPSTREAM_REAL_IP_RECURSIVE:-off}
      PROXY_READ_TIMEOUT: ${PROXY_READ_TIMEOUT:-120}
      CLIENT_MAX_BODY_SIZE: ${CLIENT_MAX_BODY_SIZE:-50m}
    volumes:
      - sites:/home/frappe/frappe-bench/sites
    ports:
      - "80:8080"
    restart: unless-stopped

volumes:
  sites:
```

## Environment Configuration

### For Database Server (hanzo-db)
```env
DB_ROOT_PASSWORD=secure_root_password
DB_NAME=hanzo
DB_USER=hanzo
DB_PASSWORD=secure_db_password
```

### For Application Server (hanzo-app)
```env
HANZO_IMAGE=hanzo/erp
VERSION=latest
DB_HOST=hanzo-db.your-domain.com
DB_PORT=3306
REDIS_HOST=hanzo-db.your-domain.com
```

### For Proxy Server (hanzo-proxy)
```env
HANZO_IMAGE=hanzo/erp
VERSION=latest
APP_SERVER_HOST=hanzo-app.your-domain.com
FRAPPE_SITE_NAME_HEADER=$host
```

## Cloudflare Tunnel Configuration

Each Dokploy application should have its own Cloudflare Tunnel:

1. **hanzo-db tunnel**: Internal access only (not exposed publicly)
   - Hostname: `hanzo-db.internal.your-domain.com`
   - Service: `http://localhost:3306` (MariaDB)
   - Service: `http://localhost:6379` (Redis Cache)
   - Service: `http://localhost:6380` (Redis Queue)

2. **hanzo-app tunnel**: Internal access only
   - Hostname: `hanzo-app.internal.your-domain.com`
   - Service: `http://localhost:8000` (Backend)
   - Service: `http://localhost:9000` (WebSocket)

3. **hanzo-proxy tunnel**: Public access
   - Hostname: `erp.your-domain.com`
   - Service: `http://localhost:80`

## Deployment Steps

1. **Deploy Database Server First**
   ```bash
   # In Dokploy, create app "hanzo-db"
   # Upload the M server docker-compose.yml
   # Set environment variables
   # Deploy
   ```

2. **Deploy Application Server**
   ```bash
   # Create app "hanzo-app"
   # Upload the F server docker-compose.yml
   # Set DB_HOST to hanzo-db tunnel hostname
   # Deploy
   ```

3. **Deploy Proxy Server**
   ```bash
   # Create app "hanzo-proxy"
   # Upload the N server docker-compose.yml
   # Set APP_SERVER_HOST to hanzo-app tunnel hostname
   # Deploy
   ```

4. **Create Initial Site**
   ```bash
   # SSH into hanzo-app container
   docker exec -it hanzo-app-backend-1 bash
   
   # Create new site
   bench new-site erp.your-domain.com \
     --db-root-password $DB_ROOT_PASSWORD \
     --admin-password admin \
     --install-app erpnext
   
   # Set as default site
   bench use erp.your-domain.com
   ```

## Building Custom Hanzo Images

Create a Dockerfile for the Hanzo rebrand:

```dockerfile
FROM frappe/erpnext:latest

# Replace Frappe branding
RUN find /home/frappe -name "*.py" -o -name "*.js" -o -name "*.html" | \
    xargs sed -i 's/Frappe/Hanzo/g'

# Add custom Hanzo apps if needed
# COPY --chown=frappe:frappe ./custom-apps /home/frappe/frappe-bench/apps/

# Rebuild assets
RUN cd /home/frappe/frappe-bench && \
    bench build
```

Build and push to registry:
```bash
docker build -t hanzo/erp:latest .
docker push hanzo/erp:latest
```

## Monitoring and Maintenance

1. **Logs**: Each Dokploy app will have its own log viewer
2. **Backups**: Configure automated backups for the MariaDB volume
3. **Updates**: Use Dokploy's deployment features to update images
4. **Scaling**: Add more F servers behind the N server load balancer

## Security Considerations

1. Use Cloudflare Access to protect internal services
2. Enable SSL/TLS on all Cloudflare Tunnels
3. Rotate database passwords regularly
4. Keep Docker images updated
5. Use separate networks for internal communication
