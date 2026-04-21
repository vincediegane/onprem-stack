# Checklist mission 2 semaines

## Semaine 1 — Fondations

### Jour 1 — Préparation
- [ ] VM Debian/Ubuntu 22.04 LTS, 4 vCPU, 8 Go RAM, 80 Go disque
- [ ] DNS / `/etc/hosts` configuré pour `*.onprem.local`
- [ ] `./scripts/install-host.sh` (Docker, UFW, fail2ban, SSH)
- [ ] Clés SSH ajoutées, mot de passe SSH désactivé vérifié

### Jour 2 — Reverse proxy
- [ ] `docker compose up -d traefik`
- [ ] Vérifier redirect 80→443
- [ ] Vérifier dashboard `https://traefik.onprem.local` (BasicAuth)
- [ ] Let's Encrypt staging OK → bascule prod si VPS

### Jour 3 — IAM
- [ ] `docker compose up -d keycloak`
- [ ] Login admin
- [ ] Vérifier import realm `onprem` (alice / bob)
- [ ] Régénérer secrets clients en prod

### Jour 4 — GED
- [ ] Préparer montage NAS (`mount.nfs` ou `cifs`)
- [ ] `docker compose up -d nextcloud`
- [ ] Premier login admin → installer apps `user_oidc`
- [ ] Configurer provider OIDC vers Keycloak
- [ ] Test login alice via SSO

### Jour 5 — Intranet
- [ ] `docker compose up -d intranet`
- [ ] Test endpoints `/public/ping` (200), `/api/me` (401 sans token)
- [ ] Test JWT (cf README quickstart)

## Semaine 2 — Sécurité, monitoring, livraison

### Jour 6 — VPN
- [ ] `docker compose up -d wireguard`
- [ ] Récupérer `peer1.conf`, tester depuis poste client
- [ ] Vérifier accès aux services internes via VPN uniquement

### Jour 7 — Monitoring
- [ ] `docker compose up -d prometheus grafana node-exporter cadvisor`
- [ ] Vérifier targets Prometheus toutes UP
- [ ] Importer dashboards Grafana (Node Exporter Full id 1860, cAdvisor 14282)

### Jour 8 — Hardening
- [ ] Audit `lynis audit system`
- [ ] Vérifier fail2ban actif (`fail2ban-client status`)
- [ ] Pare-feu : test depuis l'extérieur (nmap)
- [ ] Vérifier que toutes les BDD sont bien sur réseau `internal`

### Jour 9 — Sauvegardes
- [ ] Lancer `./scripts/backup.sh` manuellement
- [ ] Vérifier taille / contenu des archives
- [ ] Configurer cron `0 2 * * *`
- [ ] Configurer rotation et alerting si échec

### Jour 10 — Test de restauration ⚠️
- [ ] Sur VM jetable : `./scripts/restore.sh <backup>`
- [ ] Vérifier login Keycloak / fichiers Nextcloud / dashboards Grafana
- [ ] Documenter durée RTO réelle

### Jour 11 — Documentation
- [ ] Compléter `runbook.md` (restart, logs, incidents)
- [ ] Diagramme réseau finalisé
- [ ] Inventaire des secrets (où, qui y a accès)

### Jour 12 — Tests de charge / chaos
- [ ] `ab` ou `k6` sur intranet
- [ ] Tuer un container, vérifier `restart: unless-stopped`
- [ ] Vérifier alertes Prometheus

### Jour 13 — Recette client
- [ ] Démo SSO end-to-end
- [ ] Démo backup/restore
- [ ] Démo VPN
- [ ] Walkthrough Grafana

### Jour 14 — Handover
- [ ] Transfert credentials (gestionnaire de mots de passe)
- [ ] Formation équipe : 1h runbook + 1h démo
- [ ] Signature PV de recette
