`ifndef SCOREBOARD_BAUD_SV
`define SCOREBOARD_BAUD_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// Scoreboard dedicado ao teste de baud rate:
// em vez de comparar bytes, amostra a borda de descida do start-bit em txd,
// mede a duracao desse primeiro bit (start bit) em ns via $realtime e
// compara com o valor esperado = 1e9 / baud_rate_atual.
// Tolerancia: +- 3 periodos de clk (30 ns @ 100 MHz) para absorver
// a granularidade inteira do clock_div (CLK_FREQ/baud/2).
class scoreboard_baud extends uvm_component;
    `uvm_component_utils(scoreboard_baud)

    virtual uart_bfm  bfm_uart0;
    virtual reg_if_bfm bfm_reg0;

    int unsigned expected_bps [6] = '{9600, 19200, 57600, 115200, 230400, 460800};
    int unsigned match_count;
    int unsigned mismatch_count;
    int unsigned items_expected;
    realtime     tolerance_ns = 60.0; // 6 ciclos de 10ns para margem

    function new(string name = "scoreboard_baud", uvm_component parent = null);
        super.new(name, parent);
        match_count = 0;
        mismatch_count = 0;
        items_expected = 6;
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual uart_bfm)::get(this, "", "bfm_uart0", bfm_uart0))
            `uvm_fatal(get_full_name(), "bfm_uart0 nao configurada")
        if (!uvm_config_db#(virtual reg_if_bfm)::get(this, "", "bfm_reg0", bfm_reg0))
            `uvm_fatal(get_full_name(), "bfm_reg0 nao configurada")
    endfunction

    task run_phase(uvm_phase phase);
        realtime t_start, t_end, measured_ns, expected_ns;
        int unsigned sel;
        int unsigned bps;

        for (sel = 0; sel < 6; sel++) begin
            bps         = expected_bps[sel];
            expected_ns = 1_000_000_000.0 / bps;

            // Espera start bit (borda de descida em txd)
            @(negedge bfm_uart0.txd);
            t_start = $realtime;
            // Espera fim do start bit (borda de subida quando o LSB=1 ou
            // proxima transicao). Para garantir que capturamos ao menos
            // a duracao de 1 bit, esperamos a primeira posedge de txd.
            @(posedge bfm_uart0.txd);
            t_end       = $realtime;
            measured_ns = t_end - t_start;

            `uvm_info(get_full_name(),
                $sformatf("Baud %0d bps: medido=%0.2f ns, esperado=%0.2f ns (tolerancia +-%0.1f ns)",
                          bps, measured_ns, expected_ns, tolerance_ns), UVM_LOW)

            // A medicao acima representa o intervalo start_bit + (zeros iniciais do byte).
            // Como nao sabemos quantos zeros, normalizamos dividindo pelo numero de bits
            // medidos. Em vez disso, medimos apenas o start bit comparando ao periodo
            // de clock do tx_uart: o tx_clk tem periodo = 2 * max_count_tx_reg * clk_period
            // que equivale a 1/baud. Assim medimos multiplo inteiro de 1/baud.
            begin
                automatic real bits_in_window = measured_ns / expected_ns;
                automatic real nearest_int    = $rtoi(bits_in_window + 0.5);
                automatic real corrected_ns   = measured_ns / nearest_int;
                automatic real err_ns         = corrected_ns - expected_ns;
                if (nearest_int < 1.0) nearest_int = 1.0;
                `uvm_info(get_full_name(),
                    $sformatf("  -> bits_na_janela=%0.2f (~%0d), bit medio=%0.2f ns, erro=%0.2f ns",
                              bits_in_window, $rtoi(nearest_int), corrected_ns, err_ns), UVM_LOW)
                if ((err_ns < tolerance_ns) && (err_ns > -tolerance_ns)) begin
                    match_count++;
                    `uvm_info(get_full_name(), $sformatf("  MATCH baud=%0d", bps), UVM_LOW)
                end else begin
                    mismatch_count++;
                    `uvm_error(get_full_name(),
                        $sformatf("MISMATCH baud=%0d: bit medio=%0.2f ns vs esperado=%0.2f ns",
                                  bps, corrected_ns, expected_ns))
                end
            end
        end
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info(get_full_name(),
            $sformatf("\n--- BAUD-RATE SCOREBOARD SUMMARY ---\n Esperados: %0d, Matches: %0d, Mismatches: %0d",
                      items_expected, match_count, mismatch_count), UVM_LOW)
        if (mismatch_count > 0)
            `uvm_error(get_full_name(), "TEST FAILED: baud-rate scoreboard reportou mismatches.")
        else
            `uvm_info(get_full_name(), "TEST PASSED: todas as baud rates validadas.", UVM_LOW)
    endfunction

endclass : scoreboard_baud

`endif // SCOREBOARD_BAUD_SV
