SHELL := bash
.SHELLFLAGS := -euo pipefail -c

# Arquivo compose e configurações do Vivado
COMPOSE_FILE    := docker/docker-compose.yml
VIVADO_SETTINGS := /workspace/2025.2/Vivado/settings64.sh
UVM_DIR         := /workspace/uvm_activity
SIM_SCRIPT      := $(UVM_DIR)/scripts/sim_uvm_xsim.sh

# Teste a rodar (sobrescreva na linha de comando: make sim UVM_TEST=uart_baud_rate_test)
UVM_TEST ?= uart_test

COMPOSE := docker compose -f $(COMPOSE_FILE)

.PHONY: help build shell sim sim-all sim-baseline sim-baud sim-parity sim-gui

help:
	@printf "\n%-32s %s\n" "Target" "Descrição"
	@printf "%-32s %s\n"   "------" "---------"
	@printf "%-32s %s\n"   "make build"             "Constrói a imagem Docker"
	@printf "%-32s %s\n"   "make shell"              "Abre shell dentro do container"
	@printf "%-32s %s\n"   "make sim"                "Roda uart_test (headless)"
	@printf "%-32s %s\n"   "make sim UVM_TEST=X"     "Roda o teste X (headless)"
	@printf "%-32s %s\n"   "make sim-baseline"       "Roda uart_test"
	@printf "%-32s %s\n"   "make sim-baud"           "Roda uart_baud_rate_test"
	@printf "%-32s %s\n"   "make sim-parity"         "Roda uart_parity_error_test"
	@printf "%-32s %s\n"   "make sim-all"            "Roda os 3 testes em sequência"
	@printf "%-32s %s\n"   "make sim-gui"            "Abre Vivado GUI com formas de onda"
	@printf "%-32s %s\n"   "make sim-gui UVM_TEST=X" "GUI para o teste X"
	@printf "\n"
	@printf "Pré-requisito para GUI: WSLg ativo (Windows 11) e DISPLAY=:0 no WSL2\n\n"

build:
	env UID=$$(id -u) GID=$$(id -g) $(COMPOSE) build

shell:
	env UID=$$(id -u) GID=$$(id -g) $(COMPOSE) run --rm vivado bash

# ── Modo headless ────────────────────────────────────────────────────────────

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

# ── Modo GUI ─────────────────────────────────────────────────────────────────
#
# Pré-requisitos no host:
#   - Windows 11 com WSLg (já incluso por padrão)
#   - DISPLAY=:0 exportado no terminal WSL2
#
# Fluxo:
#   1. Roda headless para garantir compilação e elaboração do snapshot
#   2. Reabre xsim em modo GUI carregando wave.tcl (sinais + run all)

sim-gui: sim
	env UID=$$(id -u) GID=$$(id -g) $(COMPOSE) run --rm vivado bash -c \
		'source $(VIVADO_SETTINGS) && \
		 cd $(UVM_DIR)/work/sim/$(UVM_TEST) && \
		 xsim work.testbench \
		   --testplusarg "UVM_TESTNAME=$(UVM_TEST)" \
		   --testplusarg "UVM_VERBOSITY=UVM_LOW" \
		   --testplusarg "seed=1" \
		   -gui \
		   -wdb work.testbench.wdb \
		   -tclbatch $(UVM_DIR)/wave.tcl \
		   -log simulate_gui.log'
