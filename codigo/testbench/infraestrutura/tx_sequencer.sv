`ifndef TX_SEQUENCER_SV
`define TX_SEQUENCER_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "uart_item.sv"

class tx_sequencer extends uvm_sequencer #(uart_item);
    `uvm_component_utils(tx_sequencer)

    function new(string name = "tx_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

endclass : tx_sequencer

`endif // TX_SEQUENCER_SV