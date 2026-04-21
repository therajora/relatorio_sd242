`ifndef UART_PARITY_ERROR_TEST_SV
`define UART_PARITY_ERROR_TEST_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "environment.sv"
`include "parity_error_sequence.sv"

// Teste de injecao e deteccao de erro de paridade.
// Usa o caminho RX: o BFM empurra tramas por rxd com paridade correta/errada
// e o scoreboard le o bit 14 de reg0_config (rx_error) para decidir PASS/FAIL.
class uart_parity_error_test extends uvm_test;
    `uvm_component_utils(uart_parity_error_test)

    uart_environment uart_env;

    // Analysis port local para alimentar o scoreboard com o valor esperado
    // de rx_error (= inject_parity_error do item).
    uvm_tlm_analysis_fifo #(bit) inject_fifo;

    function new(string name = "uart_parity_error_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        uvm_config_db#(uvm_active_passive_enum)::set(this, "uart_env.rx_ag", "is_active", UVM_ACTIVE);
        // tx_ag precisa estar ativo para o reg_if_bfm ser excitado
        // (monitor_csr, configure_csr, clk). Nao enviaremos bytes pelo tx.
        uvm_config_db#(uvm_active_passive_enum)::set(this, "uart_env.tx_ag", "is_active", UVM_ACTIVE);
        uvm_config_db#(string)::set(this, "*", "test_mode", "parity");
        uart_env = uart_environment::type_id::create("uart_env", this);
    endfunction

    task run_phase(uvm_phase phase);
        parity_error_sequence seq;
        uart_item             item;
        phase.raise_objection(this);

        seq = parity_error_sequence::type_id::create("parity_error_sequence");

        // Espera CSR inicial do tx_driver aplicar (baseline: paridade off).
        #5us;
        // Re-configurar o CSR para habilitar paridade EVEN.
        // NOTA: a convencao do DUT esta invertida em relacao ao BFM:
        //   reg0_config[2]=parity_type:  0 -> DUT usa ~^data (= ODD na BFM)
        //                               1 -> DUT usa  ^data (= EVEN na BFM)
        // Usamos parity_type=1 para que DUT e BFM concordem em EVEN parity.
        // reg0_config[0]=rst, [1]=parity_enable, [2]=parity_type(1=even no DUT),
        // [3]=stop2, [6:4]=data_len, [11:7]=baud (21 -> 115200)
        uart_env.tx_ag.tx_drv.bfm_reg0.configure_csr(0, 1, 1, 0, 3'd7, 5'd21);
        #2us;

        `uvm_info(get_full_name(), "Iniciando sequence de paridade no rx_sqr...", UVM_LOW)
        fork
            seq.start(uart_env.rx_ag.rx_sqr);
            feed_expected(seq);
        join_any
        // garante que o scoreboard consumiu todos os itens
        wait (uart_env.par_scb.match_count + uart_env.par_scb.mismatch_count == 10);
        #100us;
        phase.drop_objection(this);
    endtask

    // Enfileira no scoreboard o valor esperado de rx_error em ordem.
    task feed_expected(parity_error_sequence seq);
        // Repete a mesma ordem da sequence (os bits [0..4]=0, [5..9]=1)
        bit expected [10] = '{0,0,0,0,0, 1,1,1,1,1};
        for (int i = 0; i < 10; i++) begin
            uart_env.par_scb.injected_fifo.write(expected[i]);
            // Espaca a entrega para nao saturar a fila antes do scoreboard
            // consumir (o scoreboard usa get() bloqueante). Espera minima.
            #1ns;
        end
    endtask

endclass : uart_parity_error_test

`endif // UART_PARITY_ERROR_TEST_SV
