`ifndef TX_AGENT_SV
`define TX_AGENT_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "tx_sequencer.sv"
`include "tx_driver.sv"
`include "tx_monitor.sv"

class tx_agent extends uvm_agent;
    `uvm_component_utils(tx_agent)

    tx_sequencer tx_sqr;
    tx_driver    tx_drv;
    tx_monitor   tx_mon;

    function new(string name = "tx_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(uvm_active_passive_enum)::get(this, "", "is_active", is_active)) begin
            is_active = UVM_ACTIVE;
        end

        if (is_active == UVM_ACTIVE) begin
            `uvm_info(get_full_name(), "Building ACTIVE agent: Driver and Sequencer included.", UVM_HIGH)
            tx_sqr = tx_sequencer::type_id::create("tx_sqr", this);
            tx_drv = tx_driver   ::type_id::create("tx_drv", this);
        end
        else begin
            `uvm_info(get_full_name(), "Building PASSIVE agent: Only Monitor included.", UVM_HIGH)
        end

        tx_mon = tx_monitor::type_id::create("tx_mon", this);

        if (!uvm_config_db#(virtual uart_bfm)::get(this, "", "bfm_uart0", tx_mon.bfm_uart0)) begin
            `uvm_fatal("RX_AGENT", "Virtual interface 'bfm_uart0' not set for Monitor.")
        end

        if (!uvm_config_db#(virtual reg_if_bfm)::get(this, "", "bfm_reg0", tx_mon.bfm_reg0)) begin
            `uvm_fatal("RX_AGENT", "Virtual interface 'bfm_reg0' not set for Monitor.")
        end

        // 1st difference: TX driver uses register interface
        if (is_active == UVM_ACTIVE) begin
            if (!uvm_config_db#(virtual reg_if_bfm)::get(this, "", "bfm_reg0", tx_drv.bfm_reg0)) begin
                `uvm_fatal("RX_AGENT", "Virtual interface 'bfm_reg0' not set for Driver.")
            end
        end
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (is_active == UVM_ACTIVE) begin
            tx_drv.seq_item_port.connect(tx_sqr.seq_item_export);
            `uvm_info(get_full_name(), "Connected driver to sequencer.", UVM_MEDIUM)
        end
    endfunction : connect_phase

endclass : tx_agent

`endif // TX_AGENT_SV