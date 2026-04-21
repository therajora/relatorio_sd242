`ifndef COVERAGE_SV
`define COVERAGE_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class coverage extends uvm_subscriber #(bit [7:0]);
    `uvm_component_utils(coverage)

    protected bit [7:0] data;
    protected string agent_name; // To identify if it's RX or TX scoreboard

    covergroup uart_cg;
        coverpoint data {
            bins all_values[] = {[8'h00:8'hFF]};
        }
    endgroup : uart_cg

    function new(string name = "coverage", uvm_component parent = null);
        super.new(name, parent);
        uart_cg = new();
    endfunction : new

    function void set_agent_name(string name);
        agent_name = name;
    endfunction

    function void write(bit [7:0] t);
        data = t;
        uart_cg.sample();
    endfunction : write

    function void report_phase(uvm_phase phase);
        `uvm_info(get_full_name(), $sformatf("\n--- %s COVERAGE REPORT ---\nCoverage: %0.2f%%\n", 
            agent_name, uart_cg.get_coverage()), UVM_LOW)
    endfunction : report_phase

endclass : coverage

`endif // COVERAGE_SV