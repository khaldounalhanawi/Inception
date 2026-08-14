include src/.env

NAME = inception

COMPOSE = docker compose -f src/docker-compose.yml

all: up

hosts:
	@if ! grep -q "$(DOMAIN_NAME)" /etc/hosts; then \
		sudo sh -c 'echo "\n#for Inception server\n$(LOCAL_IP) $(DOMAIN_NAME)" >> /etc/hosts'; \
	fi

secrets:
	@mkdir -p secrets
	@if ! [ -f secrets/db_password.txt ]; then \
		echo "YourDbPassword" > secrets/db_password.txt;fi
	@if ! [ -f secrets/db_root_password.txt ]; then \
		echo "YourDbRootPassword" > secrets/db_root_password.txt;fi
	@if ! [ -f secrets/wp_admin_password.txt ]; then \
		echo "YourAdminPassword" > secrets/wp_admin_password.txt;fi
	@if ! [ -f secrets/wp_guest_password.txt ]; then \
		echo "YourGuestPassword" > secrets/wp_guest_password.txt;fi

setup:
	sudo mkdir -p $(DATA_PATH)/data/database
	sudo mkdir -p $(DATA_PATH)/data/wordpress

up: secrets hosts setup
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

start:
	$(COMPOSE) start

stop:
	$(COMPOSE) stop

logs:
	$(COMPOSE) logs -f

services:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down -v

fclean:
	$(COMPOSE) down -v --rmi all
	sudo rm -rf $(DATA_PATH)

re: fclean all
