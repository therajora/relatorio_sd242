`ifndef PARITY_ERROR_SEQUENCE_SV
`define PARITY_ERROR_SEQUENCE_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "uart_item.sv"

// Sequence que gera 10 itens: 5 com paridade correta (inject_parity_error=0)
// e 5 com paridade invertida (inject_parity_error=1). Paridade even em todos
// para simplicidade do teste (poderia randomizar, mas o CSR do DUT e fixado
// pelo teste). Data totalmente aleatoria.
class parity_error_sequence extends uvm_sequence #(uart_item);
    `uvm_object_utils(parity_error_sequence)

    int item_count;

    function new(string name = "parity_error_sequence");
        super.new(name);
    endfunction

    virtual task body();
        uart_item seq_item;
        bit expected [10] = '{0,0,0,0,0, 1,1,1,1,1};
        item_count = 0;
        for (int i = 0; i < 10; i++) begin
            seq_item = uart_item::type_id::create($sformatf("seq_item_par_%0d", i));
            start_item(seq_item);
            if (!seq_item.randomize() with {
                inject_parity_error == expected[i];
                parity_type         == 1'b0;   // even fixo (CSR parity_type=0)
            }) begin
                `uvm_error(get_full_name(), "randomize() falhou em parity_error_sequence")
            end
            item_count++;
            `uvm_info(get_full_name(),
                $sformatf("Item %0d: data=0x%02h inject_err=%0b",
                          item_count, seq_item.data, seq_item.inject_parity_error), UVM_LOW)
            finish_item(seq_item);
        end
    endtask

endclass : parity_error_sequence

`endif // PARITY_ERROR_SEQUENCE_SV
