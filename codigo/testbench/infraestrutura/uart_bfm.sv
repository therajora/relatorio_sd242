`ifndef UART_BFM_SV
`define UART_BFM_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

interface uart_bfm;
    // BFM variables
    real clk_freq = 100_000_000.0; 

    // DUT specific signals
    bit clk;
    bit rst_n;

    // UART protocol signals
    bit txd='1;
    bit rxd='1;
    //bit cts;
    //bit rts;

    // Clock generation
    task automatic generate_clock(
        input   real    freq    = 100_000_000.0, 
        input   bit     clk_pol = 0,
        input   real    delay   = 0.0
    );
        clk_freq = freq;
        clk = ~clk_pol;
        #(delay);
        forever begin
            clk = ~clk;
            #(1.0 / (2.0 * clk_freq) * 1e9);
        end
    endtask : generate_clock

    // Reset assertion
    task automatic reset_pulse(
        input   bit     rst_pol     = '0,
        input   int     rst_width   = 2,
        input   string  rst_type    = "Sync", 
        input   bit     rst_edge    = 1
    );
        if (rst_type == "Sync") begin
            if (rst_edge)
                @(posedge clk);
            else
                @(negedge clk);
        end
        rst_n = rst_pol;

        if (rst_type == "Async") begin 
            #(rst_width);
        end else begin
            repeat (rst_width) begin
                if (rst_edge)
                @(posedge clk);
                else
                @(negedge clk);
            end
        end
        rst_n = ~rst_pol;
    endtask : reset_pulse

    // Baud-rate timer
    task automatic bit_timer(
        input   real    baud_rate   = 115_200,
        input   real    num_period  = 1.0
    );  
        int num_clock_cycles = int'(((clk_freq / baud_rate) * num_period) + 0.5);
        repeat (num_clock_cycles) @(posedge clk);
    endtask : bit_timer

    // Send method (encoding)
    task send(
        input byte      data,
        input  int      data_len    = 8,
        input real      baud_rate   = 115_200,
        input string    parity_type = "none",
        input bit       stop_bit    = 0,
        // Quando 1, o bit de paridade enviado e invertido (injecao de erro).
        input bit       inject_parity_error = 0
    );
        bit parity_bit;
        // start bit
        @(posedge clk);
        rxd = 1'b0;
        bit_timer(baud_rate);
        // data bits
        for (int i=0; i < data_len; i++) begin
            rxd = data[i];
            bit_timer(baud_rate);
        end
        // parity (com suporte a injecao de erro)
        if (parity_type == "even") begin
            parity_bit = (^data);
            rxd = inject_parity_error ? ~parity_bit : parity_bit;
            if (inject_parity_error)
                `uvm_info("UART_BFM", $sformatf("Injetando ERRO de paridade (even): data=0x%02h bit_ok=%0b enviando=%0b",
                          data, parity_bit, rxd), UVM_LOW)
            bit_timer(baud_rate);
        end else if (parity_type == "odd") begin
            parity_bit = ~(^data);
            rxd = inject_parity_error ? ~parity_bit : parity_bit;
            if (inject_parity_error)
                `uvm_info("UART_BFM", $sformatf("Injetando ERRO de paridade (odd): data=0x%02h bit_ok=%0b enviando=%0b",
                          data, parity_bit, rxd), UVM_LOW)
            bit_timer(baud_rate);
        end
        // stop bit 1 (mandatory)
        rxd = 1'b1;
        bit_timer(baud_rate);
        // stop bit 2 (optional)
        if (stop_bit == '1) begin
            rxd = 1'b1;
            bit_timer(baud_rate);
        end
        repeat (2) bit_timer(baud_rate);
    endtask : send

    // Receive method (decoding) for txd line
    task automatic receive_tx(
        output byte     data,
        input  int      data_len    = 8,
        input  real     baud_rate   = 115_200,
        input  string   parity_type = "none",
        input  bit      stop_bit    = 0
    );
        // start bit
        @(negedge txd);
        bit_timer(baud_rate, 1.5);
        // data bits
        data = 8'h00;
        for (int i = 0; i < data_len; i++) begin
            data[i] = txd;
            bit_timer(baud_rate);
        end
        // parity
        if (parity_type == "even") begin
            if (txd !== (^data)) `uvm_info("UART_BFM", "Error on UART parity bit (even parity).", UVM_MEDIUM);
            bit_timer(baud_rate);
        end else if (parity_type == "odd") begin
            if (txd !== ~(^data)) `uvm_info("UART_BFM", "Error on UART parity bit (odd parity).", UVM_MEDIUM);
            bit_timer(baud_rate);
        end
        // stop bit 1 (mandatory)
        if (txd !== '1) `uvm_info("UART_BFM", "Error on 1st stop bit.", UVM_MEDIUM);
        bit_timer(baud_rate);

        // stop bit 2 (optional)
        if (stop_bit == '1) begin
            if (txd !== '1) `uvm_info("UART_BFM", "Error on 2nd stop bit.", UVM_MEDIUM);
        end
    endtask : receive_tx

    // Receive method (decoding) for rxd line
    task automatic receive_rx(
        output byte     data,
        input  int      data_len    = 8,
        input  real     baud_rate   = 115_200,
        input  string   parity_type = "none",
        input  bit      stop_bit    = 0
    );
        // start bit
        @(negedge rxd);
        bit_timer(baud_rate, 1.5);
        // data bits
        data = 8'h00;
        for (int i = 0; i < data_len; i++) begin
            data[i] = rxd;
            bit_timer(baud_rate);
        end
        // parity
        if (parity_type == "even") begin
            if (rxd !== (^data)) `uvm_info("UART_BFM", "Error on UART parity bit (even parity).", UVM_MEDIUM);
            bit_timer(baud_rate);
        end else if (parity_type == "odd") begin
            if (rxd !== ~(^data)) `uvm_info("UART_BFM", "Error on UART parity bit (odd parity).", UVM_MEDIUM);
            bit_timer(baud_rate);
        end
        // stop bit 1 (mandatory)
        if (rxd !== '1) `uvm_info("UART_BFM", "Error on 1st stop bit.", UVM_MEDIUM);
        bit_timer(baud_rate);

        // stop bit 2 (optional)
        if (stop_bit == '1) begin
            if (rxd !== '1) `uvm_info("UART_BFM", "Error on 2nd stop bit.", UVM_MEDIUM);
        end
    endtask : receive_rx

endinterface //uart_bfm

`endif // UART_BFM_SV