-include .envrc
export

uname_OS := $(shell uname -s)
user_UID := $(shell id -u)
user_GID := $(shell id -g)
current_uid ?= "${user_UID}:${user_GID}"

ifeq ($(uname_OS),Darwin)
	user_UID := 1001
	user_GID := 1001
endif

docker_folder := $(if $(docker_folder),$(docker_folder),./docker)
# Passing the >_ options option
options := $(if $(options),$(options),--env-file $(docker_folder)/.env)
# Passing the >_ up_options option
up_options := $(if $(up_options),$(up_options),--force-recreate --no-build --no-deps)
# Passing the >_ common_options option
common_options := $(if $(common_options),$(common_options),--compatibility --ansi=auto)

# ==================================================================================== #
# HELPERS
# ==================================================================================== #

# internal functions
define message_failure
	"\033[1;31m ❌$(1)\033[0m"
endef

define message_success
	"\033[1;32m ✅$(1)\033[0m"
endef

define message_info
	"\033[0;34m❕$(1)\033[0m"
endef

# ==================================================================================== #
# DOCKER
# ==================================================================================== #

.PHONY: docker/config-env
docker/config-env:
	@cd docker && cp -n .env.compose .env || true
	@cd docker && sed -i "/^# PWD/c\PWD=$(shell pwd)" .env
	@cd docker && sed -i "/^# ROOT_PATH/c\ROOT_PATH=$(shell pwd)" .env
	@cd docker && sed -i "/# USER_UID=.*/c\USER_UID=$(user_UID)" .env
	@cd docker && sed -i "/# USER_GID=.*/c\USER_GID=$(user_GID)" .env
	@cd docker && sed -i "/^# CURRENT_UID/c\CURRENT_UID=${current_uid}" .env
	@cd docker && cp .envrc.example .envrc
	@cd docker/mysql && cp .env.container .env
	@cd docker/php/services/app && cp .env.container .env
	@cd docker/php/services/queue && cp .env.container .env
	@cd docker/php/services/scheduler && cp .env.container .env
	@echo
	@echo $(call message_success, Run \`make docker/config-env\` successfully executed)

.PHONY: docker/healthcheck
docker/healthcheck:
	@timeout=60; counter=0; \
	printf "\n\033[3;33mEsperando healthcheck do container de banco de dados \"$${container}\" = \"healthy\" ⏳ \033[0m\n" ; \
	until [[ "$$(docker container inspect -f '{{.State.Health.Status}}' $${container})" == "healthy" ]] ; do \
		printf '.' ; \
		if [[ $${timeout} -lt $${counter} ]]; then \
			printf "\n\033[1;31mERROR: Timed out waiting for \"$${container}\" to come up/healthy ❌\033[0m\n\n" ; \
			exit 1 ; \
		fi ; \
		\
		printf "\n\033[35mWaiting for \"$${container}\" to be ready/healthy ($${counter}/$${timeout}) ⏱ \033[0m\n" ; \
		sleep 5s; counter=$$((counter + 5)) ; \
	done
	@echo
	@echo $(call message_success, HEALTHCHECK do Container \"$${container}\" OK)

.PHONY: docker/build/app
docker/build/app:
	@echo
	@echo $(call message_info, Build an image APP... 🏗)
	@echo
	docker-compose \
		-f $(docker_folder)/php/services/app/docker-compose.yml \
		--ansi=auto \
		--env-file $(docker_folder)/.env \
		build --progress=plain app

.PHONY: docker/app/up
docker/app/up:
# make -f docker/Makefile docker/app/up
	@echo
	@echo $(call message_info, Running APP Container... 🚀)
	@echo
	@$(MAKE) -f $(docker_folder)/Makefile --no-print-directory docker/service/up context="php/services/app" up_options="--force-recreate --detach --no-deps"

.PHONY: docker/minio/up
docker/minio/up:
# make -f docker/Makefile docker/minio/up
	@echo
	@echo $(call message_info, Running MinIO Container... 🗄)
	@echo
	@$(MAKE) -f $(docker_folder)/Makefile --no-print-directory docker/service/up context="minio" up_options="--force-recreate --detach --no-deps"

.PHONY: docker/queue/up
docker/queue/up:
# make -f docker/Makefile docker/queue/up
	@echo
	@echo $(call message_info, Running QUEUE Container... 🚀)
	@echo
	@$(MAKE) -f $(docker_folder)/Makefile --no-print-directory docker/service/up context="php/services/queue"

.PHONY: docker/scheduler/up
docker/scheduler/up:
# make -f docker/Makefile docker/scheduler/up
	@echo
	@echo $(call message_info, Running SCHEDULER Container... 🚀)
	@echo
	@$(MAKE) -f $(docker_folder)/Makefile --no-print-directory docker/service/up context="php/services/scheduler"

.PHONY: docker/database/up
docker/database/up:
	@echo
	@echo $(call message_info, Running Docker Database... 🚀)
	@echo
	@$(MAKE) -f $(docker_folder)/Makefile --no-print-directory docker/service/up context=mysql up_options="--force-recreate --detach"

.PHONY: docker/redis/up
docker/redis/up:
	@echo
	@echo $(call message_info, Running Docker Redis... 🚀)
	@echo
	@$(MAKE) -f $(docker_folder)/Makefile --no-print-directory docker/service/up context=redis up_options="--force-recreate --detach"

# make  docker/service/up \
		context=FOLDER_IN_SERVICES \
		options=--verbose \
		up_options="--force-recreate" \
		services="services_in_docker_compose"
.PHONY: docker/service/up
docker/service/up:
	@docker-compose -f $(docker_folder)/$(context)/docker-compose.yml \
		$(options) $(common_options) \
		up $(up_options) \
		$(if $(services),$(services),)

.PHONY: docker/up
docker/up:
# make -f docker/Makefile docker/up database_container="app_database" redis_container="app_redis"
	@echo
	@echo $(call message_info, Running Docker Application... 🚀)
	@echo
	@docker-compose -f $(docker_folder)/docker-compose.yml up
	@$(MAKE) -f $(docker_folder)/Makefile --no-print-directory docker/database/up
	@$(MAKE) -f $(docker_folder)/Makefile --no-print-directory docker/healthcheck container=$(if $(database_container),$(database_container),app_database)
	@$(MAKE) -f $(docker_folder)/Makefile --no-print-directory docker/redis/up
	@$(MAKE) -f $(docker_folder)/Makefile --no-print-directory docker/healthcheck container=$(if $(redis_container),$(redis_container),app_redis)
	@$(MAKE) -f $(docker_folder)/Makefile --no-print-directory docker/app/up
