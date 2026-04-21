# Runbook opérationnel

## Démarrer / arrêter

```bash
docker compose up -d              # tout démarrer
docker compose down               # tout arrêter (volumes conservés)
docker compose restart <service>
docker compose logs -f <service>
docker compose ps
```

## Renouvellement TLS
Automatique via Traefik. Vérifier :
```bash
docker exec traefik cat /letsencrypt/acme.json | jq '.letsencrypt.Certificates[].domain'
```

## Reset mot de passe Keycloak admin
```bash
docker exec -it keycloak /opt/keycloak/bin/kc.sh \
  bootstrap-admin user --username admin --password NewPassword!
docker compose restart keycloak
```

## Mettre Nextcloud en maintenance
```bash
docker exec -u www-data nextcloud php occ maintenance:mode --on
# ... opération ...
docker exec -u www-data nextcloud php occ maintenance:mode --off
```

## Vérifier monitoring
```bash
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job:.labels.job, health}'
```

## Incidents fréquents

| Symptôme | Cause probable | Remède |
|---|---|---|
| `acme: error 429` | Rate-limit LE prod | Passer staging, attendre 1h |
| Nextcloud 502 | Redis down | `docker compose restart nextcloud-redis` |
| Login Keycloak boucle | `KC_HOSTNAME` ≠ DNS | Corriger `.env` + restart |
| JWT invalid sur intranet | Horloge VM décalée | `timedatectl set-ntp true` |
| Backup échoue | NAS démonté | Vérifier `mount`, recréer cron |

## Mises à jour

```bash
docker compose pull
docker compose up -d
docker image prune -f
```
Toujours : **backup avant**, lire les release notes (Keycloak / Nextcloud cassent parfois).
