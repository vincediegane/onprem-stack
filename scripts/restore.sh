#!/usr/bin/env bash
# =====================================================
# Restauration depuis un dossier de backup horodaté
# Usage: ./restore.sh /var/backups/onprem/20250101-020000
# =====================================================
set -euo pipefail
SRC="${1:?Usage: $0 <backup-dir>}"
STACK_DIR="${STACK_DIR:-/opt/onprem-stack}"

cd "${STACK_DIR}"; source .env

echo ">>> ATTENTION: restauration depuis ${SRC} - tous les services vont s'arrêter."
read -p "Continuer ? (yes/NO) " ok; [[ "${ok}" == "yes" ]] || exit 1

docker compose stop nextcloud intranet keycloak

echo "==> Restore volumes"
for vol in nextcloud_app traefik_letsencrypt grafana_data prometheus_data wireguard_config; do
  [ -f "${SRC}/${vol}.tar.gz" ] || continue
  docker run --rm -v "${vol}:/data" -v "${SRC}:/backup:ro" alpine \
    sh -c "rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null; tar xzf /backup/${vol}.tar.gz -C /data"
done

echo "==> Restore Postgres Keycloak"
docker compose up -d keycloak-db
sleep 8
gunzip -c "${SRC}/keycloak.sql.gz" | docker exec -i keycloak-db psql -U keycloak -d keycloak

echo "==> Restore MariaDB Nextcloud"
docker compose up -d nextcloud-db
sleep 8
gunzip -c "${SRC}/nextcloud.sql.gz" | docker exec -i nextcloud-db mysql -u root -p"${NEXTCLOUD_DB_PASSWORD}" nextcloud

docker compose up -d
docker exec -u www-data nextcloud php occ maintenance:mode --off || true

echo "==> Restore OK"
