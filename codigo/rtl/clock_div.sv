`timescale 1ns/1ps

module clock_div #(
    parameter integer CLK_FREQ = 100_000_000 // frequência do clock de entrada em Hz
)(
    // clock and reset
    input  logic                    clk,
    input  logic                    rst,

    input  uart_baud_rate_t         baud_rate, // taxa de baud rate selecionada
    output logic                    clk_tx_out, // clock de saída para os módulos UART
    output logic                    clk_rx_out // clock de saída para os módulos UART
);

    localparam integer CNT_WIDTH   = $clog2((CLK_FREQ /50) /2);

    // registradores unsigned para controle do clock
    logic unsigned [CNT_WIDTH-1:0] counter_tx, counter_rx; // contador para divisão do clock
    logic unsigned [CNT_WIDTH-1:0] max_count, max_count_tx_reg, max_count_rx_reg; // valor máximo do contador para a taxa de baud rate selecionada
    
    always_ff @(posedge clk) begin
        if (rst) begin
            counter_tx <= '0;
            counter_rx <= '0;
            clk_tx_out <= 0;
            clk_rx_out <= 0;
            max_count_rx_reg <= '0; // armazena o valor máximo do contador para a taxa de baud rate selecionada
            max_count_tx_reg <= '0; // armazena o valor máximo do contador para a taxa de baud rate selecionada
        end else begin
            // rx clock (16x do baud rate)
            max_count_rx_reg <= max_count >> 4; // atualiza o valor máximo do contador com base na taxa de baud rate selecionada
            if (counter_rx >= max_count_rx_reg) begin
                counter_rx <= '0;
                clk_rx_out <= ~clk_rx_out; // inverte o clock de saída
            end else begin
                counter_rx <= counter_rx + 1;
            end
            
            // tx clock (1x do baud rate)
            max_count_tx_reg <= max_count; // atualiza o valor máximo do contador com base na taxa de baud rate selecionada
            if (counter_tx >= max_count_tx_reg) begin
                counter_tx <= '0;
                clk_tx_out <= ~clk_tx_out; // inverte o clock de saída
            end else begin
                counter_tx <= counter_tx + 1;
            end

        end
    end

    always_comb begin
        case (baud_rate)
            UART_BAUD_50: max_count = (CLK_FREQ / 50) / 2; // 50 bps
            UART_BAUD_75: max_count = (CLK_FREQ / 75) / 2; // 75 bps
            UART_BAUD_110: max_count = (CLK_FREQ / 110) / 2; // 110 bps
            UART_BAUD_134: max_count = (CLK_FREQ / 134) / 2; // 134 bps
            UART_BAUD_150: max_count = (CLK_FREQ / 150) / 2; // 150 bps
            UART_BAUD_200: max_count = (CLK_FREQ / 200) / 2; // 200 bps
            UART_BAUD_300: max_count = (CLK_FREQ / 300) / 2; // 300 bps
            UART_BAUD_600: max_count = (CLK_FREQ / 600) / 2; // 600 bps
            UART_BAUD_1200: max_count = (CLK_FREQ / 1200) / 2; // 1200 bps
            UART_BAUD_1800: max_count = (CLK_FREQ / 1800) / 2; // 1800 bps
            UART_BAUD_2400: max_count = (CLK_FREQ / 2400) / 2; // 2400 bps
            UART_BAUD_4800: max_count = (CLK_FREQ / 4800) / 2; // 4800 bps
            UART_BAUD_9600: max_count = (CLK_FREQ / 9600) / 2; // 9600 bps
            UART_BAUD_14400: max_count = (CLK_FREQ / 14400) / 2; // 14400 bps
            UART_BAUD_19200: max_count = (CLK_FREQ / 19200) / 2; // 19200 bps
            UART_BAUD_28800: max_count = (CLK_FREQ / 28800) / 2; // 28800 bps
            UART_BAUD_31250: max_count = (CLK_FREQ / 31250) / 2; // 31250 bps
            UART_BAUD_38400: max_count = (CLK_FREQ / 38400) / 2; // 38400 bps
            UART_BAUD_56000: max_count = (CLK_FREQ / 56000) / 2; // 56000 bps
            UART_BAUD_57600: max_count = (CLK_FREQ / 57600) / 2; // 57600 bps
            UART_BAUD_76800: max_count = (CLK_FREQ / 76800) / 2; // 76800 bps
            UART_BAUD_115200: max_count = (CLK_FREQ / 115200) / 2; // 115200 bps
            UART_BAUD_128000: max_count = (CLK_FREQ / 128000) / 2; // 128000 bps
            UART_BAUD_153600: max_count = (CLK_FREQ / 153600) / 2; // 153600 bps
            UART_BAUD_230400: max_count = (CLK_FREQ / 230400) / 2; // 230400 bps
            UART_BAUD_256000: max_count = (CLK_FREQ / 256000) / 2; // 256000 bps
            UART_BAUD_460800: max_count = (CLK_FREQ / 460800) / 2; // 460800 bps
            UART_BAUD_500000: max_count = (CLK_FREQ / 500000) / 2; // 500000 bps
            UART_BAUD_576000: max_count = (CLK_FREQ / 576000) / 2; // 576000 bps
            UART_BAUD_921600: max_count = (CLK_FREQ / 921600) / 2; // 921600 bps
            default: max_count = (CLK_FREQ / 115200) / 2; // default para 115200 bps
        endcase
    end
endmodule