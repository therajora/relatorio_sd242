`ifndef INCREMENTAL_SEQUENCE_SV
`define INCREMENTAL_SEQUENCE_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "random_sequence.sv"

class incremental_sequence extends random_sequence;
    `uvm_component_utils(incremental_sequence)

    function new(string name = "incremental_sequence", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    task body();
        req = uart_item::type_id::create("req");
        repeat (4096) begin
            start_item(req);
            req.data = req.data + 1; // Increment the data value
            `uvm_info(get_full_name(), $sformatf("Generated random data: %0h", data), UVM_MEDIUM)
            finish_item(req.data);
        end
    endtask : body

endclass : incremental_sequence

`endif // INCREMENTAL_SEQUENCE_SV