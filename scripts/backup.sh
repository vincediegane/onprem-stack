#!/usr/bin/env bash
# =====================================================
# Backup automatisé : volumes Docker + dumps SQL
# Cron suggéré : 0 2 * * *  /opt/onprem-stack/scripts/backup.sh
# =====================================================
set -euo pipefail

STACK_DIR="${STACK_DIR:-/opt/onprem-stack}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/onprem}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
TS=$(date +%Y%m%d-%H%M%S)
DEST="${BACKUP_DIR}/${TS}"
mkdir -p "${DEST}"

cd "${STACK_DIR}"
source .env

log() { echo "[$(date -Iseconds)] $*"; }

log "==> Dump Postgres (Keycloak)"
docker exec -t keycloak-db pg_dump -U keycloak -d keycloak | gzip > "${DEST}/keycloak.sql.gz"

log "==> Dump MariaDB (Nextcloud) en mode maintenance"
docker exec -u www-data nextcloud php occ maintenance:mode --on
docker exec nextcloud-db sh -c "exec mysqldump --single-transaction -u root -p'${NEXTCLOUD_DB_PASSWORD}' nextcloud" | gzip > "${DEST}/nextcloud.sql.gz"

log "==> Snapshot volumes (tar.gz)"
for vol in nextcloud_app traefik_letsencrypt grafana_data prometheus_data wireguard_config; do
  docker run --rm -v "${vol}:/data:ro" -v "${DEST}:/backup" alpine \
    tar czf "/backup/${vol}.tar.gz" -C /data .
done

docker exec -u www-data nextcloud php occ maintenance:mode --off

log "==> Données NAS (rsync incrémental)"
rsync -aH --delete "${NAS_DATA_PATH}/" "${BACKUP_DIR}/nas-mirror/" || true

log "==> Purge > ${RETENTION_DAYS} jours"
find "${BACKUP_DIR}" -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} +

log "==> Backup terminé : ${DEST}"
du -sh "${DEST}"
