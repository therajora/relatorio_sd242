`ifndef SCOREBOARD_SV
`define SCOREBOARD_SV

import uvm_pkg::*;
`include "uvm_macros.svh"

class scoreboard extends uvm_scoreboard;
    `uvm_component_utils(scoreboard)

    int match_count;
    int mismatch_count;
    protected string agent_name; // To identify if it's RX or TX scoreboard

    uvm_tlm_analysis_fifo #(bit [7:0]) command_fifo;  
    uvm_tlm_analysis_fifo #(bit [7:0]) result_fifo;  

    function new(string name = "scoreboard", uvm_component parent = null);
        super.new(name, parent);
        match_count = 0;
        mismatch_count = 0;
        command_fifo = new("command_fifo", this);
        result_fifo = new("result_fifo", this);
    endfunction : new

    function void set_agent_name(string name);
        agent_name = name;
    endfunction

    task run_phase(uvm_phase phase);
        bit [7:0] expected_cmd;
        bit [7:0] actual_res;

        forever begin
            command_fifo.get(expected_cmd);
            result_fifo.get(actual_res);

            `uvm_info(get_full_name(), $sformatf("Received expected command: 0x%h, actual result: 0x%h", expected_cmd, actual_res), UVM_LOW)

            if (expected_cmd == actual_res) begin
                `uvm_info(get_full_name(), "MATCH: Expected command matches actual result.", UVM_LOW)
                match_count++;
            end else begin
                `uvm_fatal(get_full_name(), $sformatf("MISMATCH: Expected 0x%h but got 0x%h.", expected_cmd, actual_res))
                mismatch_count++;
            end
        end
    endtask : run_phase

    function void report_phase(uvm_phase phase); 
        int total = match_count + mismatch_count;    
        real match_percentage = (match_count / total) * 100.0;
        real mismatch_percentage = (mismatch_count / total) * 100.0;

        `uvm_info(get_full_name(), $sformatf("\n--- %s SCOREBOARD SUMMARY ---\n Total Transactions Checked: %0d\n Matches: %0d (%0.2f%%)\n Mismatches: %0d (%0.2f%%)\n",
            agent_name, total, match_count,  match_percentage, mismatch_count, mismatch_percentage), UVM_LOW)
            
        if (mismatch_count > 0) begin
            `uvm_error(get_full_name(), "TEST FAILED: Scoreboard reported mismatches.")
        end else begin
            `uvm_info(get_full_name(), "TEST PASSED: All observed responses matched expected commands.", UVM_LOW)
        end 
    endfunction : report_phase

endclass : scoreboard

`endif // SCOREBOARD_SV