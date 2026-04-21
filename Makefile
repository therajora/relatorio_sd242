SHELL := bash
.SHELLFLAGS := -euo pipefail -c

# Arquivo compose e configurações do Vivado
COMPOSE_FILE  := docker/docker-compose.yml
VIVADO_SETTINGS := /workspace/2025.2/Vivado/settings64.sh
UVM_DIR       := /workspace/uvm_activity
SIM_SCRIPT    := $(UVM_DIR)/scripts/sim_uvm_xsim.sh

# Teste a rodar (sobrescreva na linha de comando: make sim UVM_TEST=uart_baud_rate_test)
UVM_TEST ?= uart_test

COMPOSE := docker compose -f $(COMPOSE_FILE)

.PHONY: help build shell sim sim-all sim-baseline sim-baud sim-parity

help:
	@printf "\n%-30s %s\n" "Target" "Descrição"
	@printf "%-30s %s\n" "------" "---------"
	@printf "%-30s %s\n" "make build"          "Constrói a imagem Docker"
	@printf "%-30s %s\n" "make shell"           "Abre shell dentro do container"
	@printf "%-30s %s\n" "make sim"             "Roda um teste (padrão: uart_test)"
	@printf "%-30s %s\n" "make sim UVM_TEST=X"  "Roda o teste X"
	@printf "%-30s %s\n" "make sim-baseline"    "Roda uart_test (baseline)"
	@printf "%-30s %s\n" "make sim-baud"        "Roda uart_baud_rate_test"
	@printf "%-30s %s\n" "make sim-parity"      "Roda uart_parity_error_test"
	@printf "%-30s %s\n" "make sim-all"         "Roda os 3 testes em sequência"
	@printf "\n"

build:
	env UID=$$(id -u) GID=$$(id -g) $(COMPOSE) build

shell:
	env UID=$$(id -u) GID=$$(id -g) $(COMPOSE) run --rm vivado bash

sim:
	env UID=$$(id -u) GID=$$(id -g) $(COMPOSE) run --rm vivado bash -c \
		'source $(VIVADO_SETTINGS) && UVM_TEST=$(UVM_TEST) bash $(SIM_SCRIPT)'

sim-baseline:
	$(MAKE) sim UVM_TEST=uart_test

sim-baud:
	$(MAKE) sim UVM_TEST=uart_baud_rate_test

sim-parity:
	$(MAKE) sim UVM_TEST=uart_parity_error_test

sim-all: sim-baseline sim-baud sim-parity
