`ifndef RX_AGENT_SV
`define RX_AGENT_SV

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "rx_sequencer.sv"
`include "rx_driver.sv"
`include "rx_monitor.sv"

class rx_agent extends uvm_agent;
    `uvm_component_utils(rx_agent)

    rx_sequencer rx_sqr;
    rx_driver    rx_drv;
    rx_monitor   rx_mon;

    function new(string name = "rx_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(uvm_active_passive_enum)::get(this, "", "is_active", is_active)) begin
            is_active = UVM_ACTIVE;
        end

        if (is_active == UVM_ACTIVE) begin
            `uvm_info(get_full_name(), "Building ACTIVE agent: Driver and Sequencer included.", UVM_HIGH)
            rx_sqr = rx_sequencer::type_id::create("rx_sqr", this);
            rx_drv = rx_driver   ::type_id::create("rx_drv", this);
        end
        else begin
            `uvm_info(get_full_name(), "Building PASSIVE agent: Only Monitor included.", UVM_HIGH)
        end

        rx_mon = rx_monitor::type_id::create("rx_mon", this);

        if (!uvm_config_db#(virtual uart_bfm)::get(this, "", "bfm_uart0", rx_mon.bfm_uart0)) begin
            `uvm_fatal("RX_AGENT", "Virtual interface 'bfm_uart0' not set for Monitor.")
        end

        if (!uvm_config_db#(virtual reg_if_bfm)::get(this, "", "bfm_reg0", rx_mon.bfm_reg0)) begin
            `uvm_fatal("RX_AGENT", "Virtual interface 'bfm_reg0' not set for Monitor.")
        end

        if (is_active == UVM_ACTIVE) begin
            if (!uvm_config_db#(virtual uart_bfm)::get(this, "", "bfm_uart0", rx_drv.bfm_uart0)) begin
                `uvm_fatal("RX_AGENT", "Virtual interface 'bfm_uart0' not set for Driver.")
            end
        end
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (is_active == UVM_ACTIVE) begin
            rx_drv.seq_item_port.connect(rx_sqr.seq_item_export);
            `uvm_info(get_full_name(), "Connected driver to sequencer.", UVM_MEDIUM)
        end
    endfunction : connect_phase

endclass : rx_agent

`endif // RX_AGENT_SV