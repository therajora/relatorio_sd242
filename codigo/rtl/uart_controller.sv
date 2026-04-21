`timescale 1ns/1ps

module uart_controller #(
    parameter integer CLK_FREQ = 100_000_000 // frequência do clock em Hz
)(
    // clock and reset
    input  logic                    clk,
    input  logic                    rst,

    // interface de registros
    input  logic            [1:0]   address,
    input  logic                    chip_select,
    input  logic                    write_enable,
    input  logic                    read_enable,
    input  logic            [31:0]  data_in,
    output logic            [31:0]  data_out,
    output logic                    irq,

    // interface uart
    output logic                    txd,
    input  logic                    rxd
);

    // wires de controle
    logic                    reg_reset;
    logic                    parity_enable;
    logic                    parity_type;
    logic                    stop_bit;
    logic            [3:0]   data_len;
    uart_baud_rate_t         baud_rate;
    logic                    rx_error;
    logic                    rx_done;
    logic                    tx_error;
    logic                    tx_done;
    logic                    tx_start;
    logic            [7:0]   data_tx;
    logic            [7:0]   data_rx;
    logic                    clk_uart_tx;
    logic                    clk_uart_rx;
    
    // instância do banco de registros
    reg_bank reg_bank_inst (
        .clk(clk),
        .rst(rst),
        // interface de registros
        .address(address),
        .chip_select(chip_select),
        .write_enable(write_enable),
        .read_enable(read_enable),
        .data_in(data_in),
        .data_out(data_out),
        .irq(irq),
        // interface de configuração
        .reg_reset(reg_reset),
        .parity_enable(parity_enable),
        .parity_type(parity_type),
        .stop_bit(stop_bit),
        .data_len(data_len),
        .baud_rate(baud_rate),
        .data_rx(data_rx),
        .rx_error(rx_error),
        .rx_done(rx_done),
        .data_tx(data_tx),
        .tx_error(tx_error),
        .tx_done(tx_done),
        .txd(txd),
        .tx_start(tx_start)
    );

    // instância do divisor de clock
    clock_div #(
        .CLK_FREQ(CLK_FREQ)
    ) clock_div_inst (
        .clk(clk),
        .rst(rst),
        .baud_rate(baud_rate),
        .clk_tx_out(clk_uart_tx),
        .clk_rx_out(clk_uart_rx)
    );

    // instância do receptor UART
    rx_uart rx_uart_inst (
        .rx_clk(clk_uart_rx), // clock do receptor
        .rx_start('1), // start é controlado pelo controlador
        .rst(reg_reset), // reset vindo do banco de registros
        .rx(rxd), // linha de recepção conectada ao rxd externo
        .length(data_len), // comprimento dos dados configurado no banco de registros
        .parity_type(parity_type), // tipo de paridade configurado no banco de registros
        .parity_en(parity_enable), // habilitação da paridade configurada no banco de registros
        .stop2(stop_bit), // configuração de stop bit vinda do banco de registros
        .rx_out(data_rx), // dados recebidos conectados ao banco de registros
        .rx_done(rx_done), // sinal de done conectado ao banco de registros
        .rx_error(rx_error) // sinal de erro conectado ao banco de registros
    );

    // instância do transmissor UART
    tx_uart tx_uart_inst (
        .tx_clk(clk_uart_tx), // clock do transmissor
        .tx_start(tx_start), // start controlado pelo controlador
        .rst(reg_reset), // reset vindo do banco de registros
        .tx_data(data_tx), // dados a serem transmitidos conectados ao banco de registros
        .length(data_len), // comprimento dos dados configurado no banco de registros
        .parity_type(parity_type), // tipo de paridade configurado no banco de registros
        .parity_en(parity_enable), // habilitação da paridade configurada no banco de registros
        .stop2(stop_bit), // configuração de stop bit vinda do banco de registros
        .tx(txd), // linha de transmissão conectada ao txd externo
        .tx_done(tx_done), // sinal de done conectado ao banco de registros
        .tx_err(tx_error) // sinal de erro conectado ao banco de registros
    );

endmodule