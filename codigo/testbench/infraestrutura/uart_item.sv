`ifndef UART_ITEM_SV
`define UART_ITEM_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// Campos "novos" (inject_parity_error, baud_select, parity_variant) convivem
// com o uso original: a sequencia aleatoria padrao so referencia .data,
// entao a adicao nao quebra compatibilidade.
class uart_item extends uvm_sequence_item;
    `uvm_object_utils(uart_item)

    rand bit       [7:0] data;

    // --- Teste de paridade ---
    // Quando 1, o BFM emite o bit de paridade invertido (paridade ERRADA)
    rand bit             inject_parity_error;
    // 0 = even, 1 = odd (usado pelo teste de paridade)
    rand bit             parity_type;

    // --- Teste de baud rate ---
    // Indice (0..5) na tabela reduzida de baud rates do teste 1
    rand bit       [2:0] baud_select;

    constraint c_default {
        soft inject_parity_error == 1'b0;
        soft baud_select         inside {[0:5]};
        soft parity_type         inside {0, 1};
    }

    function new(string name = "uart_item");
        super.new(name);
    endfunction : new

    function string convert2string();
        return $sformatf("data=0x%02h inject_err=%0b parity=%s baud_sel=%0d",
                         data, inject_parity_error,
                         parity_type ? "odd" : "even", baud_select);
    endfunction

endclass : uart_item

`endif // UART_ITEM_SV
