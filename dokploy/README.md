# Hanzo/Frappe Dokploy Deployment

This directory contains Docker Compose configurations for deploying Hanzo (Frappe/ERPNext) using Dokploy with a three-server architecture.

## Architecture Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Proxy Server  │────▶│   App Server    │────▶│    DB Server    │
│    (N Server)   │     │   (F Server)    │     │   (M Server)    │
│                 │     │                 │     │                 │
│  - Nginx        │     │  - Backend      │     │  - MariaDB      │
│  - SSL/TLS      │     │  - WebSocket    │     │  - Redis Cache  │
│  - Load Balance │     │  - Queue Workers│     │  - Redis Queue  │
└─────────────────┘     │  - Scheduler    │     └─────────────────┘
                        └─────────────────┘
```

## Directory Structure

```
dokploy/
├── db-server/          # Database and Redis services
│   ├── docker-compose.yml
│   └── .env.example
├── app-server/         # Frappe/ERPNext application services
│   ├── docker-compose.yml
│   └── .env.example
└── proxy-server/       # Nginx proxy service
    ├── docker-compose.yml
    └── .env.example
```

## Deployment Steps

### 1. Database Server Setup

1. In Dokploy, create a new application named `hanzo-db`
2. Upload `db-server/docker-compose.yml`
3. Copy `.env.example` to `.env` and configure:
   - Set strong passwords for `DB_ROOT_PASSWORD` and `DB_PASSWORD`
   - Adjust performance settings based on your server resources
4. Deploy the application
5. Note the internal hostname (e.g., `hanzo-db.internal.your-domain.com`)

### 2. Application Server Setup

1. Create a new Dokploy application named `hanzo-app`
2. Upload `app-server/docker-compose.yml`
3. Copy `.env.example` to `.env` and configure:
   - Set `DB_HOST` to the database server's internal hostname
   - Set `REDIS_CACHE_HOST` and `REDIS_QUEUE_HOST` to the same hostname
   - Use the same `DB_ROOT_PASSWORD` and `DB_PASSWORD` from step 1
   - Set a strong `ADMIN_PASSWORD` for the ERPNext admin user
4. Deploy the application
5. Note the internal hostname for backend and websocket services

### 3. Proxy Server Setup

1. Create a new Dokploy application named `hanzo-proxy`
2. Upload `proxy-server/docker-compose.yml`
3. Copy `.env.example` to `.env` and configure:
   - Set `BACKEND_HOST` and `WEBSOCKET_HOST` to the app server's internal hostname
   - Configure `FRAPPE_SITE_NAME_HEADER` based on your setup
4. Deploy the application
5. Configure public access via Cloudflare Tunnel

### 4. Initial Site Creation

After all services are running, create your first site:

```bash
# SSH into the app server
docker exec -it hanzo-backend bash

# Create a new site
bench new-site erp.hanzo.ai \
  --db-root-password YOUR_DB_ROOT_PASSWORD \
  --admin-password YOUR_ADMIN_PASSWORD \
  --install-app erpnext

# Set as default site
bench use erp.hanzo.ai
```

Or use the included `create-site` service:

```bash
# Run with the setup profile
docker-compose --profile setup up create-site
```

## Cloudflare Tunnel Configuration

### Database Server (Internal Only)
- Create tunnel: `hanzo-db-tunnel`
- Services:
  - `hanzo-db.internal.your-domain.com:3306` → MariaDB
  - `hanzo-db.internal.your-domain.com:6379` → Redis Cache
  - `hanzo-db.internal.your-domain.com:6380` → Redis Queue

### Application Server (Internal Only)
- Create tunnel: `hanzo-app-tunnel`
- Services:
  - `hanzo-app.internal.your-domain.com:8000` → Backend
  - `hanzo-app.internal.your-domain.com:9000` → WebSocket

### Proxy Server (Public)
- Create tunnel: `hanzo-proxy-tunnel`
- Service:
  - `erp.hanzo.ai` → Port 80 (HTTP)

## Security Recommendations

1. **Network Isolation**: Keep DB and App servers on internal networks only
2. **Strong Passwords**: Use complex passwords for all services
3. **SSL/TLS**: Enable SSL on Cloudflare Tunnels
4. **Access Control**: Use Cloudflare Access for internal services
5. **Regular Updates**: Keep Docker images updated

## Scaling

To scale the application:

1. **Horizontal Scaling**: Add more app servers behind the proxy
2. **Database Replication**: Set up MariaDB master-slave replication
3. **Redis Clustering**: Implement Redis Sentinel for high availability
4. **Load Balancing**: Use multiple proxy servers with Cloudflare Load Balancer

## Backup Strategy

1. **Database Backups**:
   ```bash
   docker exec hanzo-mariadb mysqldump -u root -p _hanzo > backup.sql
   ```

2. **Files Backup**:
   ```bash
   docker cp hanzo-backend:/home/frappe/frappe-bench/sites ./sites-backup
   ```

3. **Automated Backups**: Configure Dokploy's backup features or use external tools

## Troubleshooting

### Common Issues

1. **Connection Refused**: Check that all services are running and hostnames are correct
2. **Site Not Found**: Ensure the site is created and set as default
3. **Redis Connection**: Verify Redis hosts and ports in site configuration
4. **Permission Errors**: Check file ownership in volumes

### Logs

View logs for each service:
```bash
# Database logs
docker logs hanzo-mariadb

# Application logs
docker logs hanzo-backend
docker logs hanzo-queue-short

# Proxy logs
docker logs hanzo-nginx
```

## Building Custom Hanzo Images

To use custom Hanzo-branded images:

1. Fork the Frappe Docker repository
2. Update branding and push to your registry
3. Update `HANZO_IMAGE` in all `.env` files
4. Redeploy services with new images

## Support

For issues specific to:
- Dokploy deployment: Check Dokploy documentation
- Frappe/ERPNext: Visit Frappe community forums
- Hanzo customizations: Contact Hanzo support
