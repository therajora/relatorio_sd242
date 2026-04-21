`ifndef RX_DRIVER_SV
`define RX_DRIVER_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "uart_item.sv"

// Driver RX estendido com suporte a "test_mode":
//   - "default" : comportamento original (envia apenas o byte, paridade desligada)
//   - "parity"  : usa campos do item (parity_type, inject_parity_error) para
//                 chamar uart_bfm.send() com injecao opcional do erro.
class rx_driver extends uvm_driver #(uart_item);
    `uvm_component_utils(rx_driver)

    virtual uart_bfm bfm_uart0;
    string test_mode = "default";

    function new(string name = "rx_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual uart_bfm)::get(this, "", "bfm_uart0", bfm_uart0))
            `uvm_fatal(get_full_name(), "BFM not set via uvm_config_db");
        void'(uvm_config_db#(string)::get(this, "", "test_mode", test_mode));
        `uvm_info(get_full_name(), $sformatf("rx_driver test_mode=%s", test_mode), UVM_LOW)
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        uart_item command;

        fork
            bfm_uart0.generate_clock(100_000_000, 0, 0);
            bfm_uart0.reset_pulse(1, 5, "Sync", 1);
        join_any

        forever begin
            seq_item_port.get_next_item(command);
            case (test_mode)
                "parity": begin
                    string p_str = command.parity_type ? "odd" : "even";
                    `uvm_info(get_full_name(),
                        $sformatf("send parity: data=0x%02h type=%s inject_err=%0b",
                                  command.data, p_str, command.inject_parity_error), UVM_LOW)
                    bfm_uart0.send(.data(command.data),
                                   .data_len(8),
                                   .baud_rate(115_200),
                                   .parity_type(p_str),
                                   .stop_bit(1'b0),
                                   .inject_parity_error(command.inject_parity_error));
                end
                default: begin
                    bfm_uart0.send(command.data);
                end
            endcase
            seq_item_port.item_done();
        end
    endtask : run_phase

endclass : rx_driver

`endif // RX_DRIVER_SV
