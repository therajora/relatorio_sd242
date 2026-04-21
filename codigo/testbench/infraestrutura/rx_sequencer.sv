`ifndef RX_SEQUENCER_SV
`define RX_SEQUENCER_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "uart_item.sv"

class rx_sequencer extends uvm_sequencer #(uart_item);
    `uvm_component_utils(rx_sequencer)

    function new(string name = "rx_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

endclass : rx_sequencer

`endif // RX_SEQUENCER_SV