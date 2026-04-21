`ifndef UART_ENV_SV
`define UART_ENV_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "rx_agent.sv"
`include "tx_agent.sv"
`include "scoreboard.sv"
`include "scoreboard_baud.sv"
`include "scoreboard_parity.sv"
`include "coverage.sv"

class uart_environment extends uvm_env;
    `uvm_component_utils(uart_environment)

    string test_mode = "default";

    rx_agent rx_ag;
    tx_agent tx_ag;

    scoreboard rx_scb;
    scoreboard tx_scb;
    coverage   rx_cov;
    coverage   tx_cov;

    scoreboard_baud   baud_scb;
    scoreboard_parity par_scb;

    function new(string name = "uart_environment", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(string)::get(this, "", "test_mode", test_mode));
        `uvm_info(get_full_name(), $sformatf("environment test_mode=%s", test_mode), UVM_LOW)

        rx_ag = rx_agent::type_id::create("rx_ag", this);
        tx_ag = tx_agent::type_id::create("tx_ag", this);

        case (test_mode)
            "baud_rate": begin
                baud_scb = scoreboard_baud::type_id::create("baud_scb", this);
            end
            "parity": begin
                par_scb = scoreboard_parity::type_id::create("par_scb", this);
            end
            default: begin
                rx_scb = scoreboard::type_id::create("rx_scb", this);
                rx_cov = coverage  ::type_id::create("rx_cov", this);
                tx_scb = scoreboard::type_id::create("tx_scb", this);
                tx_cov = coverage  ::type_id::create("tx_cov", this);
                rx_scb.set_agent_name("RX");
                rx_cov.set_agent_name("RX");
                tx_scb.set_agent_name("TX");
                tx_cov.set_agent_name("TX");
            end
        endcase
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        case (test_mode)
            "baud_rate": begin end
            "parity":    begin end
            default: begin
                rx_ag.rx_mon.ap_command.connect(rx_scb.command_fifo.analysis_export);
                rx_ag.rx_mon.ap_command.connect(rx_cov.analysis_export);
                rx_ag.rx_mon.ap_result.connect(rx_scb.result_fifo.analysis_export);
                tx_ag.tx_mon.ap_command.connect(tx_scb.command_fifo.analysis_export);
                tx_ag.tx_mon.ap_command.connect(tx_cov.analysis_export);
                tx_ag.tx_mon.ap_result.connect(tx_scb.result_fifo.analysis_export);
            end
        endcase
    endfunction : connect_phase

endclass : uart_environment

`endif // UART_ENV_SV
