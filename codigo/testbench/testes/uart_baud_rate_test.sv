`ifndef UART_BAUD_RATE_TEST_SV
`define UART_BAUD_RATE_TEST_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "environment.sv"
`include "baud_rate_sequence.sv"

class uart_baud_rate_test extends uvm_test;
    `uvm_component_utils(uart_baud_rate_test)

    uart_environment uart_env;

    function new(string name = "uart_baud_rate_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // Config: ativa apenas o agente TX (baud rate se mede em txd)
        uvm_config_db#(uvm_active_passive_enum)::set(this, "uart_env.tx_ag", "is_active", UVM_ACTIVE);
        uvm_config_db#(uvm_active_passive_enum)::set(this, "uart_env.rx_ag", "is_active", UVM_PASSIVE);
        // Modo de teste propagado para drivers e environment
        uvm_config_db#(string)::set(this, "*", "test_mode", "baud_rate");
        uart_env = uart_environment::type_id::create("uart_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        baud_rate_sequence seq;
        phase.raise_objection(this);
        seq = baud_rate_sequence::type_id::create("baud_rate_sequence");
        `uvm_info(get_full_name(), "Iniciando sequence de baud rate no tx_sqr...", UVM_LOW)
        seq.start(uart_env.tx_ag.tx_sqr);
        // Deixa tempo para o ultimo bit de dado/stop atravessar a linha
        #50us;
        phase.drop_objection(this);
    endtask

endclass : uart_baud_rate_test

`endif // UART_BAUD_RATE_TEST_SV
