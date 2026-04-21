# 🏢 On-Premise Stack — Training Project

Infrastructure on-premise complète, dockerisée, sécurisée, monitorée. Conçue pour s'entraîner sur une mission DevOps de 2 semaines.

## Stack

| Brique | Image | URL |
|---|---|---|
| Reverse proxy + TLS | Traefik v3 | `traefik.onprem.local` |
| IAM / SSO | Keycloak 25 | `auth.onprem.local` |
| GED | Nextcloud 30 | `cloud.onprem.local` |
| Intranet | Spring Boot 3.3 (Java 21) | `intranet.onprem.local` |
| VPN | WireGuard | UDP/51820 |
| Monitoring | Prometheus + Grafana + cAdvisor + node-exporter | `grafana.onprem.local` |

## Quickstart

```bash
# 1. Bootstrap hôte (Debian/Ubuntu) — root
sudo ./scripts/install-host.sh

# 2. Configurer
cp .env.example .env && $EDITOR .env

# 3. /etc/hosts (sur la VM ET sur ton poste)
192.168.x.x  traefik.onprem.local auth.onprem.local cloud.onprem.local intranet.onprem.local grafana.onprem.local

# 4. Préparer le NAS
sudo mkdir -p /mnt/nas/nextcloud-data && sudo chown 33:33 /mnt/nas/nextcloud-data

# 5. Démarrer
docker compose up -d

# 6. Logs
docker compose logs -f traefik keycloak
```

## Comptes par défaut

- Keycloak admin : `admin` / valeur de `KEYCLOAK_ADMIN_PASSWORD`
- Realm `onprem` :
  - `alice / Alice123!` (user)
  - `bob / Bob123!` (admin)
- Nextcloud : `ncadmin` / valeur de `NEXTCLOUD_ADMIN_PASSWORD`
- Grafana : `admin` / valeur de `GRAFANA_ADMIN_PASSWORD`

## SSO

### Nextcloud ↔ Keycloak (OIDC)
Après le 1er login Nextcloud :
1. Apps → installer **Social Login** ou **OpenID Connect user backend** (`user_oidc`)
2. Provider :
   - Identifier: `keycloak`
   - Discovery: `https://auth.onprem.local/realms/onprem/.well-known/openid-configuration`
   - Client ID: `nextcloud`
   - Client secret: voir `realm-onprem.json` (à régénérer en prod)

### Spring Boot ↔ Keycloak (Resource Server JWT)
Déjà configuré dans `application.yml` via `issuer-uri`. Tester :
```bash
TOKEN=$(curl -s -X POST https://auth.onprem.local/realms/onprem/protocol/openid-connect/token \
  -d "grant_type=password" -d "client_id=intranet" \
  -d "username=alice" -d "password=Alice123!" | jq -r .access_token)
curl -H "Authorization: Bearer $TOKEN" https://intranet.onprem.local/api/me
```

## Backup / Restore

```bash
# Cron quotidien (root)
0 2 * * *  /opt/onprem-stack/scripts/backup.sh >> /var/log/onprem-backup.log 2>&1

# Restauration depuis un point précis
./scripts/restore.sh /var/backups/onprem/20250115-020000
```

**⚠️ Tester la restauration au moins une fois (jour 12 de la checklist).**

## VPN WireGuard

```bash
# Récupérer la conf client #1
docker exec wireguard cat /config/peer1/peer1.conf
# Ou QR code (mobile)
docker exec wireguard /app/show-peer 1
```

## Sécurité — checklist rapide

- [x] HTTPS forcé (redirect 80→443) par Traefik
- [x] HSTS + headers de sécurité (`middlewares.yml`)
- [x] BasicAuth sur dashboard Traefik
- [x] Réseau `internal` non routé pour les BDD
- [x] UFW : seuls 22/80/443/51820 ouverts
- [x] SSH : root login key-only, password disabled
- [x] Fail2ban : SSH + Traefik 401
- [x] Volumes persistés
- [x] Secrets via `.env` (jamais commit)

## Améliorations possibles

- Vault / SOPS pour les secrets
- Loki pour les logs centralisés
- Alertmanager + notifications
- IaC : Ansible playbook pour install-host + déploiement
- CI/CD : GitLab runner self-hosted, build de l'intranet
- Scan d'images : Trivy en pre-commit
- Backup off-site : Restic vers S3-compatible (MinIO, Backblaze)

## Documentation détaillée
- [`docs/architecture.md`](docs/architecture.md)
- [`docs/checklist-2-semaines.md`](docs/checklist-2-semaines.md)
- [`docs/runbook.md`](docs/runbook.md)
