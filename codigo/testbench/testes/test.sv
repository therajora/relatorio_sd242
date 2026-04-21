`ifndef UART_TEST_SV
`define UART_TEST_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "environment.sv"
`include "random_sequence.sv"

class uart_test extends uvm_test;
    `uvm_component_utils(uart_test)

    uart_environment uart_env;

    function new(string name = "uart_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(uvm_active_passive_enum)::set(this, "uart_env.rx_ag", "is_active", UVM_ACTIVE);
        uvm_config_db#(uvm_active_passive_enum)::set(this, "uart_env.tx_ag", "is_active", UVM_ACTIVE);
        uart_env = uart_environment::type_id::create("uart_env", this);
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        random_sequence rx_rnd_seq;
        random_sequence tx_rnd_seq;
        phase.raise_objection(this);
        rx_rnd_seq = random_sequence::type_id::create("rx_rnd_seq");
        tx_rnd_seq = random_sequence::type_id::create("tx_rnd_seq");
        `uvm_info(get_full_name(), "Starting RANDOM SEQUENCE on RX sequencer...", UVM_LOW)
        `uvm_info(get_full_name(), "Starting RANDOM SEQUENCE on TX sequencer...", UVM_LOW)
        fork
            rx_rnd_seq.start(uart_env.rx_ag.rx_sqr);
            tx_rnd_seq.start(uart_env.tx_ag.tx_sqr);
        join
        // Prevent the test from ending until all transactions have been processed by the scoreboard
        wait (uart_env.rx_scb.match_count + uart_env.rx_scb.mismatch_count == rx_rnd_seq.item_count);
        wait (uart_env.tx_scb.match_count + uart_env.tx_scb.mismatch_count == tx_rnd_seq.item_count);
        #100ns;
        phase.drop_objection(this);
    endtask : run_phase

endclass : uart_test

`endif // UART_TEST_SV