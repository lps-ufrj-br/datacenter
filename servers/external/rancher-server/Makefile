# Makefile for Rancher Server

# Load environment variables
include config.env
export $(shell sed 's/=.*//' config.env)

.PHONY: all up down logs ps shell build clean

all: up

pull:
	docker compose --env-file config.env pull

up:
	mkdir -p $(RANCHER_DATA_PATH)
	docker compose --env-file config.env up -d

up-debug:
	docker compose --env-file config.env up

down:
	docker compose --env-file config.env down

logs:
	docker compose --env-file config.env logs -f

ps:
	docker compose --env-file config.env ps

shell:
	docker compose --env-file config.env exec rancher /bin/bash

# Clean up stopped containers and unused images
clean:
	docker compose --env-file config.env down --volumes --remove-orphans
