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


# ===================== WAVE =================================
# Log everything to waveform:
log_wave -recursive *

# Light option, define which signals to log into waveform:
# log_wave /testbench/*

# --------------------- bfm_uart0 ----------------------------
#=== Divider for visual separation or group for packaging signals:
add_wave_divider "bfm_uart0_div" -color #0000FF
add_wave_group "bfm_uart0"

#=== Add all signals (*) or list them one by one:
#add_wave {{/testbench/bfm_uart0/*}}
add_wave /testbench/bfm_uart0/clk -at_wave "bfm_uart0"
add_wave /testbench/bfm_uart0/rst_n -at_wave "bfm_uart0"
add_wave /testbench/bfm_uart0/txd -at_wave "bfm_uart0"
add_wave /testbench/bfm_uart0/rxd -at_wave "bfm_uart0"

# --------------------- bfm_reg0 -----------------------------
#=== Divider for visual separation or group for packaging signals.
add_wave_divider "bfm_reg0_div" -color #FF0000
add_wave_group "bfm_reg0"

#=== Add all signals (*) or list them one by one:
#add_wave {{/testbench/bfm_reg0/*}}
add_wave /testbench/bfm_reg0/clk -at_wave "bfm_reg0"
add_wave /testbench/bfm_reg0/rst_n -at_wave "bfm_reg0"
add_wave /testbench/bfm_reg0/address -at_wave "bfm_reg0"
add_wave /testbench/bfm_reg0/chip_select -at_wave "bfm_reg0"
add_wave /testbench/bfm_reg0/write_enable -at_wave "bfm_reg0"
add_wave /testbench/bfm_reg0/read_enable -at_wave "bfm_reg0"
add_wave /testbench/bfm_reg0/data_in -at_wave "bfm_reg0"
add_wave /testbench/bfm_reg0/data_out -at_wave "bfm_reg0"
add_wave /testbench/bfm_reg0/irq -at_wave "bfm_reg0"

# ===================== RUN ==================================
run all

# ===================== COVERAGE =============================
# exec xcrg -dir . -db_name func_cov_DB -report_dir ../../report/functional_coverage -report_format html

# ===================== DEBUG ================================
puts "Simulation finished at time [current_time]"
