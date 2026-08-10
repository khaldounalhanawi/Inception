*This project has been created as part of the 42 curriculum by kalhanaw.*

# Inception

## Description

**Inception** is a 42 school project whose goal is to set up a complete, production-style web infrastructure using **Docker** and **Docker Compose** — without using any ready-made images from Docker Hub (except the base OS).

The project deploys a working **WordPress** website, served over **HTTPS only**, composed of four services, each running in its own container built from a custom `Dockerfile` on top of `debian:bookworm`:

| Service | Role |
|---|---|
| **NGINX** | Single public entry point. Terminates TLS (self-signed certificate, TLSv1.2/1.3 only) on port `443` and proxies PHP requests to WordPress via FastCGI. |
| **WordPress** | Runs on **PHP-FPM 8.2** (no nginx/apache inside). Installed and configured automatically with WP-CLI, with two pre-created users (admin + guest). |
| **MariaDB** | Stores all WordPress data. Only reachable from inside the Docker network. |
| **Redis** | Object cache for WordPress (bonus service), wired through the `redis-cache` plugin. |

### Use of Docker and sources in this project

Every service is built from a local Dockerfile under [src/requirements/](src/requirements) and orchestrated by [src/docker-compose.yml](src/docker-compose.yml). The only external *source* downloaded at build time is the base `debian:bookworm` image; the WordPress source itself is fetched from `wordpress.org` at container first boot, and WP-CLI from its official repository. All configuration (nginx vhost, PHP-FPM pool, MariaDB server settings, Redis config) is versioned in this repository and copied into the images.

### Main design choices

- **Custom images only:** every container is built from `debian:bookworm`, per the subject requirements — no `wordpress:latest` or `nginx:latest`.
- **HTTPS-only:** nginx listens exclusively on `443` with a self-signed certificate generated at image build time.
- **Separation of concerns:** PHP-FPM, the database, and the cache each live in their own container; nginx is the only service exposing a host port.
- **Docker secrets for passwords:** passwords are never written in environment variables or baked into images — they are mounted at runtime from `secrets/*.txt` into `/run/secrets/`.
- **Healthcheck-driven startup:** WordPress waits for MariaDB and Redis to report *healthy* before starting; nginx waits for WordPress. All services restart automatically (`unless-stopped`).
- **Automatic local domain:** `make` adds `<login>.42.fr` → `127.0.0.1` to `/etc/hosts` so the site is browsed by domain name, not `localhost`.
- **Persistence via bind-mounted volumes:** the database and WordPress files live on the host under `~/data/`, so containers and images can be rebuilt without losing the site.

### Technical comparisons

#### Virtual Machines vs Docker

| | Virtual Machines | Docker (used here) |
|---|---|---|
| Isolation unit | Full OS with its own kernel, virtualized hardware | Process isolated with namespaces/cgroups, **shares the host kernel** |
| Boot time | Minutes | Seconds |
| Footprint | GBs per VM, duplicated OS | MBs per container, layered images |
| Portability | Heavy images, hypervisor-dependent | `Dockerfile` + `docker-compose.yml` reproduce the stack anywhere |
| Use case | Strong isolation, different kernels/OSes | Fast, reproducible service deployment — ideal for this project |

#### Secrets vs Environment Variables

| | Environment variables | Docker secrets (used here for passwords) |
|---|---|---|
| Visibility | Readable via `docker inspect`, `env` in the container, often leaked into logs | Mounted as a file in `/run/secrets/`, visible only inside the container |
| Storage | Stored in plain text in the Compose file / image config | Kept out of images and the Compose definition |
| Rotation | Requires container recreation with new env | File-based; can be rotated without touching the image |
| Used in this project for | Non-sensitive config (domain, usernames, DB name) | All passwords: `db_password`, `db_root_password`, `wp_admin_password`, `wp_guest_password` |

#### Docker Network vs Host Network

| | Host network | Docker (bridge) networks — used here |
|---|---|---|
| Isolation | Container shares the host's network stack — any port it opens is exposed | Containers get isolated virtual networks; only explicitly `ports:`-mapped entries reach the host |
| Port conflicts | Possible with other host services | Avoided; services address each other by **container name** |
| Security | No network boundary | MariaDB and Redis are unreachable from outside — only nginx publishes `443` |
| In this project | Not used | Two bridges: `frontend` (nginx ↔ wordpress) and `backend` (wordpress ↔ mariadb/redis) |

#### Docker Volumes vs Bind Mounts

| | Plain Docker volumes | Bind mounts |
|---|---|---|
| Managed by | Docker (`/var/lib/docker/volumes/...`) | A path you choose on the host |
| Visibility of data | Hidden from the host user | Directly inspectable/editable on the host |
| This project | — | Both volumes are **bind mounts created through Compose** (`driver_opts: type: none, o: bind, device: ~/data/...`): MariaDB → `~/data/database`, WordPress → `~/data/wordpress`. This combines Docker's volume lifecycle with a known, persistent host location, as required by the subject. |

## Instructions

> **Platform:** Linux (tested on a 42 machine). Requires **Docker**, **Docker Compose v2**, **Make**, and `sudo` rights.

### 1. Clone and configure

```sh
git clone <repo-url> inception && cd inception
```

Edit [src/.env](src/.env) if needed — it defines the domain name (`<login>.42.fr`), usernames, site title, and the data path.

### 2. Create the secrets

The `secrets/` folder is **not** included in the repository. Create it with four password files (one password per line):

```sh
mkdir -p secrets
echo 'YourDbPassword'      > secrets/db_password.txt
echo 'YourDbRootPassword'  > secrets/db_root_password.txt
echo 'YourAdminPassword'   > secrets/wp_admin_password.txt
echo 'YourGuestPassword'   > secrets/wp_guest_password.txt
```

### 3. Build and run

```sh
make
```

This adds the domain to `/etc/hosts`, creates the data folders, builds the four images, and starts the stack.

### 4. Use the site

- Website: `https://<login>.42.fr` (accept the self-signed certificate warning)
- Admin panel: `https://<login>.42.fr/wp-admin` — log in with `WP_ADMIN_USER` and the password from `secrets/wp_admin_password.txt`

### Common commands

```sh
make services   # container status
make logs       # follow logs
make stop/start # pause / resume
make down       # stop and remove containers (data kept)
make clean      # also remove volumes (host data folders kept)
make fclean     # full wipe: containers, images, and all data
make re         # fclean + rebuild from scratch
```

## Resources

### Documentation and references

- [Dockerfile reference](https://docs.docker.com/reference/dockerfile/) and [Docker Compose specification](https://docs.docker.com/compose/compose-file/) — image builds, `healthcheck`, `depends_on`, `secrets`, bind-mount `driver_opts`.
- [Docker secrets](https://docs.docker.com/engine/swarm/secrets/) — runtime secret mounting under `/run/secrets/`.
- [NGINX documentation](https://nginx.org/en/docs/) — TLS configuration (`ssl_protocols`), FastCGI proxying to PHP-FPM.
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/) — `mariadb-install-db`, server configuration.
- [WordPress WP-CLI handbook](https://make.wordpress.org/cli/handbook/) — scripted install: `wp config create`, `wp core install`, `wp user create`, `wp plugin install`.
- [PHP-FPM documentation](https://www.php.net/manual/en/install.fpm.php) — pool configuration (`www.conf`).
- [Redis documentation](https://redis.io/docs/) and the [Redis Object Cache plugin](https://wordpress.org/plugins/redis-cache/) — bonus cache integration.
- 42 subject PDF and peer discussions/evaluations.

### Use of AI

AI assistance (GitHub Copilot) was used for the following tasks, always followed by manual review and testing:

- **Documentation:** drafting this `README.md`, `USER_DOC.md`, and `DEV_DOC.md` from the project's actual source files.
 development.

All architecture decisions, configuration values, and final validation (`make re`, browser tests, persistence checks) were performed by the project author.

## More information

- [USER_DOC.md](USER_DOC.md) — how to use the stack: services, start/stop, access, credentials, health checks.
- [DEV_DOC.md](DEV_DOC.md) — developer guide: full setup, Makefile/Compose commands, container and volume management, data persistence internals.
