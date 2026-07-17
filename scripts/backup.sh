#!/bin/bash
set -e

BACKUP_DIR="/mnt/storage/backups/homeserver-config"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="$BACKUP_DIR/backup_$TIMESTAMP"

echo "Creating backup at $BACKUP_PATH..."

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Backup Docker Compose files
echo "Backing up Docker Compose configuration..."
cp /opt/homeserver/docker-compose.yml "$BACKUP_PATH/"
cp /opt/homeserver/.env "$BACKUP_PATH/"
cp /opt/homeserver/README.md "$BACKUP_PATH/" 2>/dev/null || true

# Backup service configurations (not the data, just configs)
echo "Backing up service configurations..."
mkdir -p "$BACKUP_PATH/config"

# Backup entire config directory (databases, settings)
if [ -d /opt/homeserver/config ]; then
    tar -czf "$BACKUP_PATH/config.tar.gz" -C /opt/homeserver config
fi

# Backup Docker volumes list
echo "Documenting Docker volumes..."
docker volume ls > "$BACKUP_PATH/docker-volumes.txt"

# Backup container list
echo "Documenting running containers..."
docker ps -a > "$BACKUP_PATH/docker-containers.txt"

# Create restore instructions
cat > "$BACKUP_PATH/RESTORE.md" << 'EOF'
# Restore Instructions

## Quick Restore (Existing System)
1. Stop all containers: `cd /opt/homeserver && docker compose down`
2. Restore configs: `tar -xzf config.tar.gz -C /opt/homeserver/`
3. Copy docker-compose.yml and .env to /opt/homeserver/
4. Start: `docker compose up -d`

## Fresh Install Restore
1. Install Docker on new system
2. Create directory: `mkdir -p /opt/homeserver`
3. Copy docker-compose.yml and .env to /opt/homeserver/
4. Extract config: `tar -xzf config.tar.gz -C /opt/homeserver/`
5. Mount storage at /mnt/storage (contains actual data)
6. Run: `cd /opt/homeserver && docker compose up -d`

## Database Backups
Database data is in config/ directory and backed up in config.tar.gz

## User Data
Photos/files are in /mnt/storage/ (not backed up by this script)
Use ZFS snapshots or rsync for data backups
EOF

# Keep only last 7 backups
echo "Cleaning old backups (keeping last 7)..."
cd "$BACKUP_DIR"
ls -t | tail -n +8 | xargs -r rm -rf

echo "Backup complete: $BACKUP_PATH"
echo "Backup size: $(du -sh "$BACKUP_PATH" | cut -f1)"

# Git commit if in git repo
if [ -d /opt/homeserver/.git ]; then
    echo "Committing to git..."
    cd /opt/homeserver
    git add docker-compose.yml README.md
    git commit -m "Automated backup $TIMESTAMP" 2>/dev/null || echo "No changes to commit"
fi
