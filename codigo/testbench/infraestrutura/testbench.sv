`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// Includes de todos os testes disponiveis. UVM_TESTNAME seleciona
// qual deles sera instanciado via run_test().
`include "test.sv"                   // uart_test (original)
`include "uart_baud_rate_test.sv"    // novo
`include "uart_parity_error_test.sv" // novo

module testbench;

    uart_bfm bfm_uart0();
    reg_if_bfm bfm_reg0();

    uart_controller dut (
        .clk(bfm_reg0.clk),
        .rst(bfm_reg0.rst_n),
        // interface de registro
        .address(bfm_reg0.address),
        .chip_select(bfm_reg0.chip_select),
        .write_enable(bfm_reg0.write_enable),
        .read_enable(bfm_reg0.read_enable),
        .data_in(bfm_reg0.data_in),
        .data_out(bfm_reg0.data_out),
        .irq(bfm_reg0.irq),
        // interface UART
        .txd(bfm_uart0.txd),
        .rxd(bfm_uart0.rxd)
    );

    initial begin
        uvm_config_db#(virtual uart_bfm)::set(null, "*", "bfm_uart0", bfm_uart0);
        uvm_config_db#(virtual reg_if_bfm)::set(null, "*", "bfm_reg0", bfm_reg0);
        run_test();
    end

endmodule