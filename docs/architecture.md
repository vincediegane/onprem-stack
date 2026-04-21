# Architecture technique

## Schéma logique

```
                Internet (port 443/UDP 51820)
                         │
                ┌────────┴────────┐
                │     Traefik     │  ← TLS auto (Let's Encrypt)
                │  (entry: edge)  │     redirect 80→443
                └────────┬────────┘     headers sec, BasicAuth dashboard
        ┌──────┬─────────┼──────────┬───────────┐
        │      │         │          │           │
   ┌────▼──┐ ┌─▼──────┐ ┌▼─────────┐ ┌────────▼┐ ┌──────────┐
   │Keycloak│ │Nextcloud│ │Intranet  │ │ Grafana │ │WireGuard │
   │  IAM   │ │  GED    │ │SpringBoot│ │         │ │  VPN     │
   └────┬───┘ └────┬────┘ └────┬─────┘ └────┬────┘ └────┬─────┘
        │          │           │            │           │
        │          │           │ JWT        │           │ tunnel
        │          │OIDC       │ (issuer)   │           │ 10.13.13.0/24
        │          └─────► auth.onprem.local            │
        │                                                │
        │  network: internal (pas de route externe)     │
   ┌────▼─────┐ ┌──────────┐ ┌──────────┐                │
   │KC-DB     │ │NC-DB     │ │NC-Redis  │                │
   │Postgres16│ │MariaDB 11│ │Redis 7   │                │
   └──────────┘ └──────────┘ └──────────┘                │
                     │                                   │
              ┌──────▼──────┐                            │
              │   NAS       │ ← bind mount NFS/CIFS      │
              │ /mnt/nas/   │                            │
              └─────────────┘                            │
                                                         │
   network: monitoring                                   │
   ┌──────────┐ ┌──────────────┐ ┌──────────┐           │
   │Prometheus│ │node-exporter │ │ cAdvisor │           │
   └──────────┘ └──────────────┘ └──────────┘           │
                                                         │
   Pare-feu UFW: 22/tcp, 80/tcp, 443/tcp, 51820/udp ◄────┘
```

## Réseaux Docker

| Réseau | Type | Rôle |
|---|---|---|
| `edge` | bridge | Services exposés via Traefik |
| `internal` | bridge `internal: true` | BDD, Redis — pas d'accès Internet |
| `monitoring` | bridge | Prometheus scrape |

## Flux et ports

| De | Vers | Port | Protocole |
|---|---|---|---|
| Internet | Traefik | 443/tcp | HTTPS |
| Internet | Traefik | 80/tcp | HTTP → redirect |
| Internet | WireGuard | 51820/udp | VPN |
| VPN client | LAN interne | tout | via tunnel |
| Traefik | Keycloak/Nextcloud/Intranet/Grafana | interne | HTTP |
| Nextcloud | Keycloak | OIDC | HTTPS (via Traefik) |
| Intranet | Keycloak (JWKS) | HTTPS | validation JWT |
| Prometheus | tous services `*:metrics` | interne | HTTP |

## Choix techniques

- **Traefik v3** plutôt que Nginx : labels Docker = zéro config, ACME natif.
- **Keycloak 25** avec import realm JSON : reproductible, versionnable.
- **Nextcloud Apache** plutôt que FPM : simpler pour démarrer.
- **MariaDB** pour Nextcloud (recommandation officielle), **Postgres** pour Keycloak.
- **WireGuard** plutôt qu'OpenVPN : plus rapide, moins de surface d'attaque.
- **cAdvisor + node-exporter** = couverture full (host + containers).
