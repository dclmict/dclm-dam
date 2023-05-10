# https://makefiletutorial.com/

# load .env file
include ./src/.env

repo:
	@if [ -d .git ]; then \
		echo "\033[31mPlease enter github repo name: \033[0m "; \
		read -r repo; \
		gh repo create dclmict/$$repo --public --source=. --remote=origin; \
		echo "\033[31m Enter commit message\033[0m"; \
		read -r cm; \
		git add . && git commit -m "$$cm"; \
		git push --set-upstream origin main; \
	else \
		echo "\033[31mPlease enter github repo name: \033[0m "; \
		git init && git add . && git commit -m "DCLM DAM"; \
		read -r repo; \
		gh repo create dclmict/$$repo --public --source=. --remote=origin; \
		echo "\033[31m Enter commit message\033[0m"; \
		read -r cm; \
		git add . && git commit -m "$$cm"; \
		git push --set-upstream origin main; \
	fi

git:
	@if git status --porcelain | grep -q '^??'; then \
		echo "\033[31mUntracked files found::\033[0m \033[32mPlease enter commit message:\033[0m"; \
		read -r msg1; \
		git add -A; \
		git commit -m "$$msg1"; \
		read -p "Do you want to push your commit to GitHub? (yes|no): " choice; \
		case "$$choice" in \
			yes|Y|y) \
				echo "\033[32mPushing commit to GitHub...:\033[0m"; \
				git push; \
				;; \
			no|N|n) \
				echo "\033[32m Nothing to be done. Thank you...:\033[0m"; \
				exit 0; \
				;; \
			*) \
				echo "\033[32m No choice. Exiting script...:\033[0m"; \
				exit 1; \
				;; \
		esac \
	else \
		echo "\033[31mThere are no new files::\033[0m \033[32mPlease enter commit message:\033[0m"; \
		read -r msg2; \
		git commit -am "$$msg2"; \
		read -p "Do you want to push your commit to GitHub? (yes|no): " choice; \
		case "$$choice" in \
			yes|Y|y) \
				echo "\033[32mPushing commit to GitHub...:\033[0m"; \
				git push; \
				;; \
			no|N|n) \
				echo "\033[32m Nothing to be done. Thank you...:\033[0m"; \
				exit 0; \
				;; \
			*) \
				echo "\033[32m No choice. Exiting script...:\033[0m"; \
				exit 1; \
				;; \
		esac \
	fi

build:
	@if docker images | grep -q $(DIN); then \
		echo "\033[31mRemoving all dangling images\033[0m image"; \
		echo y | docker image prune --filter="dangling=true"; \
		echo "\033[31mRemoving $(DIN):$(DIV) image\033[0m"; \
		docker image rm $(DIN):$(DIV); \
		echo "Building \033[31m$(DIN):$(DIV)\033[0m image"; \
		docker build -t $(DIN):$(DIV) .; \
		docker images | grep $(DIN); \
	else \
		echo "Building \033[31m$(DIN):$(DIV)\033[0m image"; \
		docker build -t $(DIN):$(DIV) .; \
		docker images | grep $(DIN); \
	fi

push:
	cp ./ops/.env.dev ./src/.env
	echo ${DLP} | docker login -u opeoniye --password-stdin
	docker push $(DIN):$(DIV)

dev:
	cp ./ops/.env.dev ./src/.env
	cp ./docker-dev.yml ./src/docker-compose.yml
	docker compose -f ./src/docker-compose.yml --env-file ./src/.env up -d

prod:
	@if [ -d .git ]; then \
		echo "\033[31mDirectory exists, starting container...\033[0m"; \
		touch ops/.env.prod; \
		echo "\033[32mPaste .env content and save with :wq\033[0m"; \
		vim ops/.env.prod; \
		cp ./ops/.env.prod ./src/.env; \
		cp ./docker-prod.yml ./src/docker-compose.yml; \
		docker pull $(DIN):$(DIV); \
		docker compose -f ./src/docker-compose.yml --env-file ./src/.env up -d; \
	else \
		echo "\033[31mDirectory not found, setting up project...\033[0m"; \
		git clone https://github.com/dclmict/dclm-dam.git .; \
		sudo chown -R ubuntu:ubuntu .; \
		touch ops/.env.prod; \
		echo "\033[32mPaste .env content and save with :wq\033[0m"; \
		vim ops/.env.prod; \
		cp ./ops/.env.prod ./src/.env; \
		cp ./docker-prod.yml ./src/docker-compose.yml; \
		docker pull $(DIN):$(DIV); \
		docker compose -f ./src/docker-compose.yml --env-file ./src/.env up -d; \
	fi

up:
	docker compose -f ./src/docker-compose.yml --env-file ./src/.env up --detach

down:
	docker compose -f ./src/docker-compose.yml --env-file ./src/.env down

start:
	docker compose -f ./src/docker-compose.yml --env-file ./src/.env start

stop:
	docker compose -f ./src/docker-compose.yml --env-file ./src/.env stop

restart:
	docker compose -f ./src/docker-compose.yml --env-file ./src/.env.dev restart

destroy:
	docker compose -f ./src/docker-compose.yml --env-file ./src/.env down --volumes

shell:
	docker compose -f ./src/docker-compose.yml --env-file ./src/.env exec -it $(CN) bash

ps:
	docker compose -f ./src/docker-compose.yml ps

log:
	docker compose -f ./src/docker-compose.yml --env-file ./src/.env logs -f $(CN)