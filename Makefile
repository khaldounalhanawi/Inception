include src/.env

NAME = inception

COMPOSE = docker compose -f src/docker-compose.yml

all: up

hosts:
	@if ! grep -q "$(DOMAIN_NAME)" /etc/hosts; then \
		sudo sh -c 'echo "\n#for Inception server\n$(LOCAL_IP) $(DOMAIN_NAME)" >> /etc/hosts'; \
	fi

setup:
	sudo mkdir -p $(DATA_PATH)/data/database
	sudo mkdir -p $(DATA_PATH)/data/wordpress

up: hosts setup
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
