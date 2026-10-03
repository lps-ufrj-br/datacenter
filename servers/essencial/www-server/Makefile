# Makefile for WWW Server Redirects

.PHONY: all help up up-d up-debug down restart logs ps clean clean-all prune

all: up

help:
	@echo "Comandos disponíveis:"
	@echo "  make up         - Sobe os containers em background (-d)"
	@echo "  make up-debug   - Sobe os containers em modo interativo (com logs)"
	@echo "  make down       - Para e remove os containers"
	@echo "  make restart    - Reinicia os containers"
	@echo "  make logs       - Acompanha os logs em tempo real"
	@echo "  make ps         - Lista o status dos containers"
	@echo "  make clean      - Para containers, remove volumes e orphans"
	@echo "  make clean-all  - Limpa tudo: containers, volumes, redes e imagens do compose"
	@echo "  make prune      - Executa docker system prune profundo (remove recursos não utilizados)"

up:
	docker compose up -d --remove-orphans

up-debug:
	docker compose up --remove-orphans

down:
	docker compose down --remove-orphans

restart: down up

logs:
	docker compose logs -f

ps:
	docker compose ps

# Limpa containers, volumes e containers órfãos associados ao compose
clean:
	docker compose down --volumes --remove-orphans

# Limpeza completa do projeto: containers, volumes, redes e imagens locais baixadas/construídas
clean-all:
	docker compose down --volumes --rmi all --remove-orphans

# Limpeza geral do Docker no sistema
prune:
	docker system prune -a --volumes -f
