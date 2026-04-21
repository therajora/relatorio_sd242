#!/usr/bin/env bash
# ============================================================
# Simulacao UVM com xsim (Vivado) — uvm_activity/
# Espelha scripts/vuvm.sh mas com a arvore rtl/sim deste exercicio.
#
# Uso:
#   UVM_TEST=uart_test               bash uvm_activity/scripts/sim_uvm_xsim.sh
#   UVM_TEST=uart_baud_rate_test     bash uvm_activity/scripts/sim_uvm_xsim.sh
#   UVM_TEST=uart_parity_error_test  bash uvm_activity/scripts/sim_uvm_xsim.sh
#
# Variaveis opcionais:
#   UVM_VERBOSITY  (default: UVM_MEDIUM)
#   RND_SEED       (default: 1)
#   VIVADO_SETTINGS= caminho para settings64.sh (se ainda nao estiver no PATH)
# ============================================================
set -euo pipefail

UVM_TEST=${UVM_TEST:-uart_test}
UVM_VERBOSITY=${UVM_VERBOSITY:-UVM_MEDIUM}
RND_SEED=${RND_SEED:-1}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RTL_DIR="$ROOT_DIR/rtl"
SIM_DIR="$ROOT_DIR/sim"
RUN_DIR="$ROOT_DIR/work/sim/$UVM_TEST"
LOGS_DIR="$ROOT_DIR/logs/$UVM_TEST"

if [[ -n "${VIVADO_SETTINGS:-}" && -f "$VIVADO_SETTINGS" ]]; then
    # shellcheck disable=SC1090
    source "$VIVADO_SETTINGS"
fi

if ! command -v xvlog >/dev/null; then
    echo "ERROR: xvlog nao encontrado no PATH. Defina VIVADO_SETTINGS=.../settings64.sh" >&2
    exit 1
fi

mkdir -p "$RUN_DIR" "$LOGS_DIR"
cd "$RUN_DIR"

echo "============================================================"
echo " Vivado xsim — UVM test = $UVM_TEST"
echo "   Verbosity: $UVM_VERBOSITY | Seed: $RND_SEED"
echo "   Run dir  : $RUN_DIR"
echo "============================================================"

RTL_FILES=(
    "$RTL_DIR/baud_rate_type.svh"
    "$RTL_DIR/clock_div.sv"
    "$RTL_DIR/reg_bank.sv"
    "$RTL_DIR/rx_uart.sv"
    "$RTL_DIR/tx_uart.sv"
    "$RTL_DIR/uart_controller.sv"
)
TB_FILES=(
    "$SIM_DIR/uart_bfm.sv"
    "$SIM_DIR/reg_if_bfm.sv"
    "$SIM_DIR/testbench.sv"
)

echo "[1/3] xvlog (compile) ..."
xvlog -sv \
    --include "$ROOT_DIR" \
    --include "$RTL_DIR" \
    --include "$SIM_DIR" \
    "${RTL_FILES[@]}" "${TB_FILES[@]}" \
    -L uvm \
    -log xvlog_compile.log

echo "[2/3] xelab (elaborate) ..."
xelab testbench \
    -relax -s work.testbench \
    -L uvm -L work \
    -debug typical \
    -timescale 1ns/100ps \
    -log elaborate.log

echo "[3/3] xsim (simulate) ..."
set +e
xsim work.testbench \
    -runall -log simulate.log \
    -testplusarg UVM_TESTNAME="$UVM_TEST" \
    -testplusarg UVM_VERBOSITY="$UVM_VERBOSITY" \
    -testplusarg seed="$RND_SEED"
SIM_EXIT=$?
set -e

# copia logs para logs/<test>/
cp -f xvlog_compile.log elaborate.log simulate.log "$LOGS_DIR/" 2>/dev/null || true

# resumo — conta somente linhas reais emitidas pelo UVM (formato "UVM_X @").
# Evita contar as linhas de resumo final que citam "UVM_ERROR : 0" etc.
ERR_COUNT=$(grep -cE "^UVM_ERROR " simulate.log || true)
FAT_COUNT=$(grep -cE "^UVM_FATAL " simulate.log || true)
INFO_COUNT=$(grep -cE "^UVM_INFO "  simulate.log || true)
# Le tambem os totais oficiais do Report Summary (final do log)
SUMMARY_ERR=$(awk '/Report counts by severity/{flag=1;next}/^$/{flag=0}flag && /^UVM_ERROR/{print $NF}' simulate.log | tail -1)
SUMMARY_FAT=$(awk '/Report counts by severity/{flag=1;next}/^$/{flag=0}flag && /^UVM_FATAL/{print $NF}' simulate.log | tail -1)
: "${SUMMARY_ERR:=$ERR_COUNT}" "${SUMMARY_FAT:=$FAT_COUNT}"
echo "------------------------------------------------------------"
echo " Resumo: UVM_INFO=$INFO_COUNT  UVM_ERROR=${SUMMARY_ERR:-$ERR_COUNT}  UVM_FATAL=${SUMMARY_FAT:-$FAT_COUNT}"
echo " Exit code xsim: $SIM_EXIT"
echo "------------------------------------------------------------"

# falha se erro/fatal aparecerem (usa o resumo oficial do UVM)
if [[ "${SUMMARY_FAT:-0}" -gt 0 || "${SUMMARY_ERR:-0}" -gt 0 ]]; then
    echo "FAIL: simulacao reportou UVM_ERROR=$SUMMARY_ERR UVM_FATAL=$SUMMARY_FAT"
    exit 1
fi
if [[ "$SIM_EXIT" -ne 0 ]]; then
    echo "FAIL: xsim retornou $SIM_EXIT"
    exit $SIM_EXIT
fi
echo "PASS: $UVM_TEST"
