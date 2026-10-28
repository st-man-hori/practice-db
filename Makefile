PROJECT := practice-db
COMPOSE := docker compose -p $(PROJECT)
ALL_PROFILES := --profile mysql --profile postgres

DB ?=
ROWS ?= 100000
SEED ?= 42

.DEFAULT_GOAL := help
.PHONY: help up down reset seed check mysql psql env guard-db

help: ## コマンド一覧
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'

up: env guard-db ## 起動 (DB=mysql|postgres)
	$(COMPOSE) --profile $(DB) up -d --wait

down: ## 停止（両DB。データは残る）
	$(COMPOSE) $(ALL_PROFILES) down

reset: env guard-db ## ボリュームを削除して初期状態で再作成 (DB=mysql|postgres)
	$(COMPOSE) --profile $(DB) rm -sfv $(DB)
	docker volume rm -f $(PROJECT)_$(DB)-data
	$(COMPOSE) --profile $(DB) up -d --wait

seed: up ## 大量データを生成 (DB=... ROWS=注文数 SEED=42)。顧客・商品・注文は作り直す
	./scripts/seed.sh $(DB) $(ROWS) $(SEED)

check: env ## 別環境で両DBを起動し、テーブル・マスタ・seedを確認（普段のデータには触れない）
	./scripts/check.sh

mysql: ## MySQL クライアントで接続
	$(COMPOSE) --profile mysql exec mysql sh -c 'MYSQL_PWD="$$MYSQL_PASSWORD" mysql -u"$$MYSQL_USER" "$$MYSQL_DATABASE"'

psql: ## psql で接続
	$(COMPOSE) --profile postgres exec postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

env:
	@test -f .env || (cp .env.example .env && echo ".env を .env.example から作成しました")

guard-db:
	@case "$(DB)" in mysql|postgres) ;; *) echo "DB=mysql または DB=postgres を指定してください" >&2; exit 1;; esac
