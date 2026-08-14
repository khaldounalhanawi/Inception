# Inception — User Documentation

This document explains, in simple terms, how to use the **Inception** stack: what it provides, how to start and stop it, how to access the website, where the credentials live, and how to verify that everything is working.

> **Platform:** This stack is designed to run on a **Linux** machine (it stores data under `/home/<user>` and edits `/etc/hosts`).

---

## 1. What services does this stack provide?

The stack runs four services, each in its own Docker container:

| Service | What it does |
|---|---|
| **NGINX** | The web server and only public entry point. It serves the website over **HTTPS only** (port 443, TLSv1.2/TLSv1.3) using a self-signed certificate, and forwards PHP requests to WordPress. |
| **WordPress** | The website itself, running on **PHP-FPM 8.2**. It is pre-installed and pre-configured with two users (an administrator and a guest/subscriber). |
| **MariaDB** | The database where all WordPress content (pages, posts, users, settings) is stored. |
| **Redis** | An in-memory object cache that speeds up WordPress by caching database queries. |

The only port exposed to your machine is **443 (HTTPS)**. MariaDB and Redis are only reachable from inside the Docker network.

---

## 2. Starting and stopping the project

All commands are run from the **root of the repository** (where the `Makefile` is).

### Start (first time or after a reboot)

```sh
make
```

This single command will:
1. Add your domain (e.g. `login.42.fr`) to `/etc/hosts` if it isn't there yet (you may be asked for your `sudo` password).
2. Create the data folders on the host (`~/data/database` and `~/data/wordpress`).
3. Build the Docker images and start all containers in the background.

The first start takes a few minutes while the images are built and WordPress is installed.

### Stop the project

```sh
make stop      # pause the containers (data and state are kept)
make start     # resume previously stopped containers
```

### Shut down completely (containers removed, data kept)

```sh
make down
```

### Remove containers and volumes (host data folders are kept)

```sh
make clean     # stops the stack and removes containers and volumes
```

### Delete everything (containers, images and all data)

```sh
make fclean    # removes containers, images, and ALL website data from the host
```

### Restart from a clean slate

```sh
make re        # removes everything (including website data!) and rebuilds
```

> ⚠️ `make clean`, `make fclean` and `make re` delete data. `make fclean`/`make re` permanently erase the website files **and** the database from the host machine.

---

## 3. Accessing the website and the admin panel

| Page | URL |
|---|---|
| Website | `https://<your-login>.42.fr` |
| Admin panel | `https://<your-login>.42.fr/wp-admin` |

Your domain name is defined in [src/.env](src/.env) as `DOMAIN_NAME` and follows the pattern `<WP_ADMIN_USER>.42.fr`.

### About the browser security warning

The site uses a **self-signed TLS certificate**, so your browser will show a warning such as *"Your connection is not private"*. This is expected. Click **Advanced → Proceed** (wording varies by browser) to continue to the site.

---

## 4. Credentials — where they are and how to manage them

Credentials are split into two places:

### Usernames and settings — `src/.env`

[src/.env](src/.env) contains the non-secret configuration:

- `WP_ADMIN_USER` — the WordPress administrator username (also used to build the domain name).
- `WP_GUEST_USER` — a second WordPress user with the **subscriber** role.
- `WP_ADMIN_EMAIL` / `WP_GUEST_EMAIL` — the users' email addresses.
- `MYSQL_USER` / `MYSQL_DATABASE` — the database user and database name.

### Passwords — `secrets/`

Passwords are **never** stored in the `.env` file. They live as plain-text files in a `secrets/` folder at the repository root, which is injected into the containers as Docker secrets.

The folder is **Automatically generaterd on run time** in the repository 

Each file must contain **only the password**, on a single line.

| File | Used for |
|---|---|
| secrets/db_password.txt | Password of the WordPress database user (`wp_user`). |
| secrets/db_root_password.txt | MariaDB root password. |
| secrets/wp_admin_password.txt | Password for the WordPress **administrator** account. |
| secrets/wp_guest_password.txt | Password for the WordPress **guest/subscriber** account. |

Without these four files, the project will not start.

### Changing credentials

- **Before the first launch:** edit `src/.env`, then run `make`.
- **After the site is already installed:** changing `.env` or the secrets has **no effect** on existing WordPress users, because users are created only once during the initial installation. Either change the password from the WordPress admin panel (*Users → Profile*), or rebuild from scratch with `make re` (this erases all site data).
- **If a secrets/ folder already exists:** when you 'make all' again it will not create a new secrets, and therefor you would retain the passwords that already exist inside the secrects folder.

> 🔒 Never commit real passwords to a public repository. The `secrets/` folder is meant to stay private.

---

## 5. Checking that everything is running correctly

### Container status

```sh
make services
```

All four containers (`nginx`, `wordpress`, `mariadb`, `redis`) should show as `running`. MariaDB and Redis should also report `(healthy)` once their health checks pass.

### Live logs

```sh
make logs
```

Press `Ctrl+C` to stop following the logs (this does not stop the containers).

### Website check

Open `https://<your-login>.42.fr` in a browser — you should see the WordPress site titled **"Inception"**. Log in at `/wp-admin` with the admin username and the password from [secrets/wp_admin_password.txt](secrets/wp_admin_password.txt).

### Redis cache check

In the WordPress admin panel, go to **Settings → Redis**. The status should show **"Connected"**, confirming that object caching is active.

### If something is wrong

1. Look at the logs: `make logs` — each container prints its own startup messages.
2. Make sure port `443` is free (no other web server running on your machine).
3. Make sure the domain resolves: `ping <your-login>.42.fr` should answer from `127.0.0.1`. If not, run `make hosts`.
4. As a last resort, rebuild everything: `make re` (⚠️ erases all website data).
