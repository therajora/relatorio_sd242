`ifndef SCOREBOARD_PARITY_SV
`define SCOREBOARD_PARITY_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// Scoreboard do teste de paridade.
// Recebe os itens "injetados" pela sequence (via analysis port exposta pelo
// parity_error_test) e amostra o rx_error do DUT consultando get_csr
// apos cada rx_done. Confronta: inject_parity_error ESPERADO vs rx_error OBSERVADO.
class scoreboard_parity extends uvm_component;
    `uvm_component_utils(scoreboard_parity)

    virtual reg_if_bfm bfm_reg0;
    virtual uart_bfm   bfm_uart0;

    uvm_tlm_analysis_fifo #(bit) injected_fifo;

    int unsigned match_count;
    int unsigned mismatch_count;

    function new(string name = "scoreboard_parity", uvm_component parent = null);
        super.new(name, parent);
        match_count    = 0;
        mismatch_count = 0;
        injected_fifo  = new("injected_fifo", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual reg_if_bfm)::get(this, "", "bfm_reg0", bfm_reg0))
            `uvm_fatal(get_full_name(), "bfm_reg0 nao configurada")
        if (!uvm_config_db#(virtual uart_bfm)::get(this, "", "bfm_uart0", bfm_uart0))
            `uvm_fatal(get_full_name(), "bfm_uart0 nao configurada")
    endfunction

    task run_phase(uvm_phase phase);
        bit expected_err;
        bit observed_err;
        int idx = 0;
        // Aguarda inicializacao do CSR e IRQs iniciais de ready_to_transmit.
        #10us;
        forever begin
            injected_fifo.get(expected_err);
            idx++;
            // Aguarda o IRQ de rx_done para este frame.
            // Cada frame recebido gera exatamente 1 ciclo de IRQ alto.
            @(posedge bfm_reg0.irq);
            // Aguarda monitor_csr concluir a leitura de reg0 (3 ciclos internos)
            // e atualizar bfm_reg0.rx_error antes de amostrar.
            // O sticky bit em reg_bank garante que rx_error=1 e visivel pelo
            // monitor_csr mesmo que o FSM ja tenha saido do estado check_parity.
            // uart_receive limpa o sticky depois (ao ler reg2), mas o BFM
            // ja preservou o valor em bfm_reg0.rx_error.
            repeat(5) @(posedge bfm_reg0.clk);
            observed_err = bfm_reg0.rx_error;
            `uvm_info(get_full_name(),
                $sformatf("Item %0d: esperado_err=%0b observado_err=%0b",
                          idx, expected_err, observed_err), UVM_LOW)
            if (expected_err === observed_err) begin
                match_count++;
                `uvm_info(get_full_name(), "  MATCH", UVM_LOW)
            end else begin
                mismatch_count++;
                `uvm_error(get_full_name(),
                    $sformatf("MISMATCH item %0d: esperado=%0b observado=%0b",
                              idx, expected_err, observed_err))
            end
        end
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info(get_full_name(),
            $sformatf("\n--- PARITY SCOREBOARD SUMMARY ---\n Matches: %0d, Mismatches: %0d",
                      match_count, mismatch_count), UVM_LOW)
        if (mismatch_count > 0)
            `uvm_error(get_full_name(), "TEST FAILED: parity scoreboard reportou mismatches.")
        else
            `uvm_info(get_full_name(), "TEST PASSED: flag rx_error consistente com injecoes.", UVM_LOW)
    endfunction

endclass : scoreboard_parity

`endif // SCOREBOARD_PARITY_SV
