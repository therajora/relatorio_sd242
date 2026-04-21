`ifndef TX_MONITOR_SV
`define TX_MONITOR_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

class tx_monitor extends uvm_monitor;
    `uvm_component_utils(tx_monitor)

    virtual uart_bfm bfm_uart0;
    virtual reg_if_bfm bfm_reg0;

    uvm_analysis_port#(bit [7:0]) ap_command;
    uvm_analysis_port#(bit [7:0]) ap_result;

    function new(string name = "tx_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        ap_command = new("ap_command", this);
        ap_result  = new("ap_result", this);
        
        if (!uvm_config_db#(virtual uart_bfm)::get(this, "", "bfm_uart0", bfm_uart0))
            `uvm_fatal(get_full_name(), "BFM not set via uvm_config_db");
        if (!uvm_config_db#(virtual reg_if_bfm)::get(this, "", "bfm_reg0", bfm_reg0))
            `uvm_fatal(get_full_name(), "Register Interface BFM not set via uvm_config_db");
    endfunction : build_phase

    // task for sampling command interface
    task command_monitor_task();
        bit [7:0] data_read;
        forever begin
            bfm_reg0.get_if_write01(data_read);
            ap_command.write(data_read);
            @(posedge bfm_reg0.clk); 
        end
    endtask

    // task for sampling result interface
    task result_monitor_task();
        bit [7:0] data_read;
        forever begin
            bfm_uart0.receive_tx(data_read);
            ap_result.write(data_read);
        end
    endtask

    task run_phase(uvm_phase phase);
        fork
            command_monitor_task();
            result_monitor_task();
        join_none
    endtask : run_phase

endclass : tx_monitor

`endif // TX_MONITOR_SV