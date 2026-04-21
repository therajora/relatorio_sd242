`ifndef BAUD_RATE_SEQUENCE_SV
`define BAUD_RATE_SEQUENCE_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "uart_item.sv"

// Sequence que percorre os 6 baud rates mapeados no tx_driver,
// enviando 1 byte aleatorio por taxa. O driver reconfigura o CSR
// conforme item.baud_select antes de cada uart_send.
class baud_rate_sequence extends uvm_sequence #(uart_item);
    `uvm_object_utils(baud_rate_sequence)

    int item_count;

    function new(string name = "baud_rate_sequence");
        super.new(name);
    endfunction : new

    virtual task body();
        uart_item seq_item;
        item_count = 0;
        for (int i = 0; i < 6; i++) begin
            seq_item = uart_item::type_id::create($sformatf("seq_item_baud_%0d", i));
            start_item(seq_item);
            if (!seq_item.randomize() with { baud_select == i; inject_parity_error == 0; }) begin
                `uvm_error(get_full_name(), "randomize() falhou no baud_rate_sequence")
            end
            item_count++;
            `uvm_info(get_full_name(),
                $sformatf("Item %0d -> baud_select=%0d data=0x%02h",
                          item_count, seq_item.baud_select, seq_item.data), UVM_LOW)
            finish_item(seq_item);
        end
    endtask : body

endclass : baud_rate_sequence

`endif // BAUD_RATE_SEQUENCE_SV
