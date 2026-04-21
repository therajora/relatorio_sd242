`ifndef REG_IF_BFM_SV
`define REG_IF_BFM_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

interface reg_if_bfm;

    // DUT specific signals
    bit clk;
    bit rst_n;

    semaphore interface_access_key = new(1);

    // register-based interface
    bit [1:0]  address;
    bit        chip_select;
    bit        write_enable;
    bit        read_enable;
    bit [31:0] data_in;
    bit [31:0] data_out;
    bit        irq;

    // global CSR variables
    bit data_available;
    bit ready_to_transmit;
    bit tx_error;
    bit rx_error;

    // Clock generation
    task generate_clock(
        input   real    freq    = 100_000_000.0, 
        input   bit     clk_pol = 0,
        input   real    delay   = 0.0
    );
        clk = ~clk_pol;
        #(delay);
        forever begin
            clk = ~clk;
            #(1.0 / (2.0 * freq) * 1e9);
        end
    endtask : generate_clock

    // Reset assertion
    task reset_pulse(
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

    // Task to perform a register write
    task write_register(
        input bit [31:0] data_w,
        input bit [1:0] addr
    );
        @(posedge clk);
        address = addr;
        data_in = data_w;
        chip_select = 1;
        write_enable = 1;
        read_enable = 0;
        @(posedge clk);
        data_in = '0;
        chip_select = 0;
        write_enable = 0;
    endtask : write_register

    // Task to perform a register read
    task read_register(
        output bit [31:0] data_r,
        input bit [1:0] addr
    );
        @(posedge clk);
        address = addr;
        chip_select = 1;
        write_enable = 0;
        read_enable = 1;
        @(posedge clk);
        @(posedge clk);
        data_r = data_out;
        chip_select = 0;
        read_enable = 0;
    endtask : read_register

    task monitor_csr(input real clk_freq = 100_000_000,
                     input real baud_rate = 115_200);
        reg [31:0] data_r;
        automatic integer delay_baud_rate = ((clk_freq / baud_rate) / 16);
        forever begin
            @(posedge irq);
            read_register(data_r, 2'b00);
            tx_error = data_r[15];
            rx_error = data_r[14];
            ready_to_transmit = data_r[13];
            data_available = data_r[12];
        end
    endtask : monitor_csr

    task get_csr(input real clk_freq = 100_000_000,
                     input real baud_rate = 115_200);
        reg [31:0] data_r;
        @(posedge clk)
        read_register(data_r, 2'b00);
        tx_error = data_r[15];
        rx_error = data_r[14];
        ready_to_transmit = data_r[13];
        data_available = data_r[12];
    endtask : get_csr

    task uart_send(
        input bit [7:0] data_tx
    );
        // Wait until ready to transmit
        while(~ready_to_transmit)
            @(posedge clk);
        interface_access_key.get(1);
        write_register({24'b0, data_tx}, 2'b01);
        ready_to_transmit = 0;
        interface_access_key.put(1);
    endtask : uart_send

    task uart_receive(
        output bit [7:0] data_rx
    );
        reg [31:0] data_r;
        // Wait until data is available
        while(~data_available)
            @(posedge clk);
        interface_access_key.get(1);
        read_register(data_r, 2'b10);
        data_rx = data_r[7:0];
        data_available = 0;
        interface_access_key.put(1);
    endtask : uart_receive

    task configure_csr(
        input logic         reg_reset,
        input logic         parity_enable,
        input logic         parity_type,
        input logic         stop_bit,
        input logic [2:0]   data_len,
        input logic [4:0]   baud_rate
    );
        write_register({20'b0, baud_rate, data_len, stop_bit, parity_type, parity_enable, reg_reset }, 2'b00);
    endtask : configure_csr

    task get_if_write01 (
        output bit [7:0] data
    );
        // while not writing to address 01
        forever begin
            @(posedge chip_select);
            if (write_enable && (address == 2'b01)) begin
                @(negedge clk);
                data = data_in[7:0];
                break;
            end
        end    
    endtask

endinterface //reg_if_bfm

`endif // REG_IF_BFM_SV