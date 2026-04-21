# ============================================================
# Vivado Simulator (xsim) script
# Description: This script allows configuration and control of
# the compilation, elaboration and simulation flows with the
# built-in Vivado simulator.
#
# Author: Elivander Judas Tadeu Pereira - Inatel
# Date: 2026-03-20
# Version: 1.0
#
# Version history:
# 1.0 Initial version aiming source code from UVM_PRIMER book.
#
# ============================================================


# ===================== UVM controls =========================
# Comment these 2 lines to allow changing parameter in runtime
set SCRIPT_TARGET   "all"
set GUI_MODE        "no-gui"

# UVM controls
set UVM_TEST        "uart_test"
set UVM_VERBOSITY   "UVM_MEDIUM"
set UVM_ARGS        [list ]
set RND_SEED        1

# ================== Project definitions =====================
# Main directories
set ROOT_DIR        [pwd]
set RUN_DIR         "$ROOT_DIR/work/sim"

# Design (DUT) and Testbench (simulation) directories
set RTL_PATHS       "$ROOT_DIR/rtl"
set TB_PATHS        "$ROOT_DIR/sim"

# Design (DUT) file list (VHDL and Verilog/SV separated)
set XVHDL_RTL_FILES [list ]
set XVLOG_RTL_FILES [list "$RTL_PATHS/baud_rate_type.svh" \
                          "$RTL_PATHS/clock_div.sv" \
                          "$RTL_PATHS/reg_bank.sv" \
                          "$RTL_PATHS/rx_uart.sv" \
                          "$RTL_PATHS/tx_uart.sv" \
                          "$RTL_PATHS/uart_controller.sv" ]

# Testbench (simulation) file list (VHDL and Verilog/SV separated)
set XVHDL_TB_FILES  [list ]
set XVLOG_TB_FILES  [list "$TB_PATHS/uart_bfm.sv" \
                          "$TB_PATHS/reg_if_bfm.sv" \
                          "$TB_PATHS/uart_item.sv" \
                          "$TB_PATHS/transaction.sv" \
                          "$TB_PATHS/coverage.sv" \
                          "$TB_PATHS/scoreboard.sv" \
                          "$TB_PATHS/scoreboard_baud.sv" \
                          "$TB_PATHS/scoreboard_parity.sv" \
                          "$TB_PATHS/rx_sequencer.sv" \
                          "$TB_PATHS/tx_sequencer.sv" \
                          "$TB_PATHS/rx_monitor.sv" \
                          "$TB_PATHS/tx_monitor.sv" \
                          "$TB_PATHS/rx_driver.sv" \
                          "$TB_PATHS/tx_driver.sv" \
                          "$TB_PATHS/rx_agent.sv" \
                          "$TB_PATHS/tx_agent.sv" \
                          "$TB_PATHS/environment.sv" \
                          "$TB_PATHS/incremental_sequence.sv" \
                          "$TB_PATHS/random_sequence.sv" \
                          "$TB_PATHS/baud_rate_sequence.sv" \
                          "$TB_PATHS/parity_error_sequence.sv" \
                          "$TB_PATHS/test.sv" \
                          "$TB_PATHS/uart_baud_rate_test.sv" \
                          "$TB_PATHS/uart_parity_error_test.sv" \
                          "$TB_PATHS/testbench.sv" ]

# Name of the top level simulation module 
set TOP_NAME        "testbench"
