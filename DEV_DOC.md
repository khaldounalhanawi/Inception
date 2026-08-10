# Inception — Developer Documentation

This document describes how a developer can set up, build, run, and manage the **Inception** project from scratch, and how its data is stored and persisted.

---

## 1. Architecture overview

Four containers, built from local Dockerfiles (all based on `debian:bookworm`), orchestrated by Docker Compose from [src/docker-compose.yml](src/docker-compose.yml):

```
                host :443 (HTTPS only)
                  │
              ┌───▼────┐
              │ nginx  │  TLS termination (self-signed cert), FastCGI proxy
              └───┬────┘
        frontend  │  network
              ┌───▼────────┐
              │ wordpress  │  PHP-FPM 8.2 + WP-CLI, listens on :9000
              └───┬────┬───┘
        backend   │    │
           ┌──────▼─┐ ┌▼──────┐
           │ mariadb│ │ redis │  :3306 / :6379, internal only
           └────────┘ └───────┘
```

- **Networks:** `frontend` (nginx ↔ wordpress) and `backend` (wordpress ↔ mariadb/redis). Only nginx publishes a host port (`443:443`).
- **Startup order:** `wordpress` waits for `mariadb` and `redis` to be *healthy* (`mariadb -e "SELECT 1"` and `redis-cli ping` healthchecks); `nginx` waits for `wordpress`. All services use `restart: unless-stopped`.
- **Entrypoint scripts:** each image runs an `init.sh` that performs first-boot setup, then `exec`s the service binary:
  - [mariadb/tools/init.sh](src/requirements/mariadb/tools/init.sh) — initializes the datadir if empty, boots a temporary networkless server, applies [init.sql](src/requirements/mariadb/tools/init.sql) (database + user, password injected via `sed` from the Docker secret), shuts it down, then runs `mariadbd` as the `mysql` user via `gosu`.
  - [wordpress/tools/init.sh](src/requirements/wordpress/tools/init.sh) — rejects admin usernames containing `admin`/`administrator` (subject requirement), downloads WordPress and creates `wp-config.php` via WP-CLI on first boot (DB host `mariadb`, Redis host `redis:6379`), runs `wp core install`, creates the guest subscriber, installs/activates the `redis-cache` plugin and enables the object cache. All steps are idempotent.
  - [nginx/tools/init.sh](src/requirements/nginx/tools/init.sh) — substitutes `DOMAIN_NAME` into [nginx.conf](src/requirements/nginx/conf/nginx.conf) at container start.
  - [redis/tools/init.sh](src/requirements/redis/tools/init.sh) — launches `redis-server` with [redis.conf](src/requirements/redis/conf/redis.conf).
- **TLS:** the nginx image generates a 2048-bit RSA self-signed certificate at build time (`openssl req -x509`, CN = `DOMAIN_NAME`, valid 365 days). Only TLSv1.2 and TLSv1.3 are enabled.

---

## 2. Set up the environment from scratch

Complete setup, in order: **1) install the prerequisites → 2) configure `src/.env` → 3) create the `secrets/` folder → 4) build and launch with `make`.**

### Prerequisites

- Linux (the volume paths and `/etc/hosts` handling assume a Linux host; on macOS adjust `DATA_PATH` in [src/.env](src/.env)).
- **Docker Engine** + **Docker Compose v2** (`docker compose` plugin).
- **Make**.
- `sudo` rights (needed for `/etc/hosts` and for creating/removing the data directory).

### Configuration files

1. **`src/.env`** — included by both the [Makefile](Makefile) and Docker Compose. Adjust at least:

   | Variable | Meaning |
   |---|---|
   | `WP_ADMIN_USER` | WordPress admin username. Must **not** contain `admin`/`administrator` (enforced by the init script). Also drives `DOMAIN_NAME` and `DATA_PATH`. |
   | `DOMAIN_NAME` | Site domain, conventionally `<login>.42.fr`. |
   | `MYSQL_DATABASE` / `MYSQL_USER` | Database name and DB user for WordPress. |
   | `WP_TITLE`, `WP_ADMIN_EMAIL`, `WP_GUEST_USER`, `WP_GUEST_EMAIL` | Site title and the two pre-created WP users. |
   | `DATA_PATH` | Host path for persistent data (default `/home/${WP_ADMIN_USER}` → `~/data/...`). |
   | `LOCAL_IP` | IP written into `/etc/hosts` for the domain (default `127.0.0.1`). |

   > Note: values are written as `KEY = value` (with spaces) and are consumed by GNU Make, so keep that exact format.

2. **`secrets/`** — this folder is **not shipped with the repository**; you must create it yourself at the repo root, with four plain-text files, each containing only the password on one line:

   ```sh
   mkdir -p secrets

   echo 'YourDbPassword'      > secrets/db_password.txt        # password for MYSQL_USER
   echo 'YourDbRootPassword'  > secrets/db_root_password.txt   # MariaDB root password
   echo 'YourAdminPassword'   > secrets/wp_admin_password.txt  # WordPress admin password
   echo 'YourGuestPassword'   > secrets/wp_guest_password.txt  # WordPress guest password
   ```

   Compose mounts them into the containers at `/run/secrets/<name>` (see the `secrets:` blocks in [docker-compose.yml](src/docker-compose.yml)); the init scripts read them with `cat`. They are never baked into the images. The build fails at `docker compose up` if any of the four files is missing.

### First build and launch

```sh
make          # = make up: hosts entry + data dirs + docker compose up -d --build
```

`make up` depends on two helper targets:

- `make hosts` — appends `127.0.0.1 <DOMAIN_NAME>` to `/etc/hosts` if missing.
- `make setup` — creates `$(DATA_PATH)/data/database` and `$(DATA_PATH)/data/wordpress`.

First boot takes a few minutes (image builds, WordPress download, DB initialization).

---

## 3. Makefile and Docker Compose commands

### Makefile targets

| Target | What it runs / does |
|---|---|
| `make` / `make up` | `hosts` + `setup`, then `docker compose up -d --build` |
| `make down` | `docker compose down` (stops and removes containers; volumes and images stay) |
| `make stop` / `make start` | `docker compose stop` / `start` (pause/resume without removing) |
| `make logs` | `docker compose logs -f` (follow all service logs) |
| `make services` | `docker compose ps` (container status, incl. health) |
| `make hosts` | Adds the domain to `/etc/hosts` |
| `make setup` | Creates the host data directories |
| `make clean` | `docker compose down -v` — also deletes the named volumes' mountpoints' registration (the host bind data itself stays) |
| `make fclean` | `down -v --rmi all` + `sudo rm -rf $(DATA_PATH)` — **full wipe**: containers, volumes, images, and all host data |
| `make re` | `fclean` + `up` — rebuild from absolute scratch |

### Direct Compose / Docker commands

The Makefile wraps `docker compose -f src/docker-compose.yml`. Useful one-offs:

```sh
# Rebuild a single service after editing its Dockerfile/conf
docker compose -f src/docker-compose.yml up -d --build wordpress

# Shell into a container
docker exec -it wordpress bash
docker exec -it mariadb mariadb -u wp_user -p wordpress

# Follow logs of one service
docker logs -f nginx

# Inspect health status
docker inspect --format '{{.State.Health.Status}}' mariadb

# Volume management
docker volume ls                          # src_database, src_wordpress-data
docker volume inspect src_wordpress-data  # shows the bind-mount source on the host
docker volume rm src_database             # only works after `make down`/`make clean`
docker volume prune                       # remove all unused volumes (careful)

# Container management
docker stop nginx wordpress mariadb redis # stop individual containers
docker start wordpress                    # restart one container
docker restart nginx                      # restart after editing nginx.conf
docker compose -f src/docker-compose.yml up -d --force-recreate wordpress
```

---

## 4. Domain name setup (replaces localhost)

The project **automatically points your domain name at the local machine**, so the site is reached as `https://<login>.42.fr` instead of `https://localhost`.

This is handled by the `hosts` target in the [Makefile](Makefile), which runs on every `make` / `make up`:

```sh
sudo sh -c 'echo "\n#for Inception server\n127.0.0.1 <login>.42.fr" >> /etc/hosts'
```

How it works:

1. `DOMAIN_NAME` (from [src/.env](src/.env), default `<WP_ADMIN_USER>.42.fr`) is mapped to `LOCAL_IP` (default `127.0.0.1`) in `/etc/hosts`.
2. The entry is only added **if it isn't already present**, so repeated `make` runs stay clean.
3. The same `DOMAIN_NAME` is also used as the nginx `server_name`, the TLS certificate CN, and the WordPress site URL — so the certificate, vhost, and site address all match the hosts entry.

If the domain does not resolve (e.g. `ping <login>.42.fr` fails), run `make hosts` manually. To switch machines or IPs, edit the line in `/etc/hosts` or change `LOCAL_IP` in `src/.env`.

---

## 5. Data storage and persistence

### Where the data lives

Both volumes are **bind mounts** into the host filesystem, declared at the bottom of [docker-compose.yml](src/docker-compose.yml):

| Volume | Mounted in container | Host path |
|---|---|---|
| `database` | `/var/lib/mysql` (MariaDB datadir) | `$(DATA_PATH)/data/database` |
| `wordpress-data` | `/var/www/html` (WordPress files, incl. `wp-config.php`, uploads, plugins) | `$(DATA_PATH)/data/wordpress` |

With the default `.env`, `DATA_PATH=/home/<login>`, so data sits under `/home/<login>/data/`.

### What persists and when

- `make stop`, `make start`, `make down`, and even container/image rebuilds **preserve** the site: the database and the WordPress files survive on the host.
- First-boot initialization is guarded and idempotent: MariaDB checks for `/var/lib/mysql/<dbname>`, WordPress checks for `wp-config.php` and `wp core is-installed`. Re-running the stack against existing data simply reuses it.
- `make fclean` (and therefore `make re`) deletes `$(DATA_PATH)` entirely — the only path that destroys data.

### Practical notes

- **Backup** = copy `$(DATA_PATH)/data/` (database + wordpress) plus the `secrets/` folder and `src/.env`.
- **Reset just the site:** `make fclean && make` — the init scripts will re-run their first-boot logic on empty directories.
- **Changing credentials after install:** WordPress users and the DB password are created once at first boot; editing `.env`/`secrets` afterwards does not retroactively update them. Use WP-CLI inside the container (`wp user update ... --user_pass=...`) or rebuild.
- **nginx configuration:** `DOMAIN_NAME` is templated into `nginx.conf` at *container start*, while the TLS certificate's CN is baked at *image build* from the `DOMAIN_NAME` build arg — after changing the domain, force a full image rebuild (`docker compose build --no-cache nginx` or `make re`).
