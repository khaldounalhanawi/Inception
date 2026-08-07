include src/.env

NAME = inception

COMPOSE = docker compose -f src/docker-compose.yml

DATA_PATH = /home/$(WP_ADMIN_USER)

all: up

setup:
	sudo mkdir -p $(DATA_PATH)/data/database
	sudo mkdir -p $(DATA_PATH)/data/wordpress

up: setup
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down -v

fclean:
	$(COMPOSE) down -v --rmi all
	sudo rm -rf $(DATA_PATH)

re: fclean all

# add logs, ps start stop 