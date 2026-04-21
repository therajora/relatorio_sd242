// tabela de enumeração dos baud_rate da uart
`timescale 1ns/1ps

module reg_bank (
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

    // interface de configuração
    output logic                    reg_reset,
    output logic                    parity_enable,
    output logic                    parity_type,
    output logic                    stop_bit,
    output logic            [3:0]   data_len,
    output uart_baud_rate_t         baud_rate,

    // uart rx
    input  logic            [7:0]   data_rx,
    input  logic                    rx_error,
    input  logic                    rx_done,

    // uart tx
    output logic            [7:0]   data_tx,
    input  logic                    tx_error,
    input  logic                    tx_done,
    input  logic                    txd,
    output logic                    tx_start
);
    
    // declaração dos registradores internos
    logic [15:0] reg0_config; // read-write
    logic [7:0] reg1_data_tx; // write only
    logic [7:0] reg2_data_rx; // read only

    logic data_available_rx, data_available_flag;
    logic ready_to_transmit_tx, ready_to_transmit_flag;

    logic tx_done_rise, rx_done_rise;
    logic tx_done_prev, rx_done_prev;

    // implementação da interface de registradores
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            reg0_config <= '0;
            reg1_data_tx <= '0;
            reg2_data_rx <= '0;
            data_available_rx <= '0;
            ready_to_transmit_tx <= '1;
            data_available_flag <= '0;
            ready_to_transmit_flag <= '1;
            irq <= '0;
        end
        else begin
            if (chip_select) begin
                // escreve os regs 0 e 1 pela interface de registros
                if(write_enable) begin
                    case (address)
                        2'd0: reg0_config[11:0] <= data_in[11:0];
                        2'd1: begin
                            reg1_data_tx <= data_in[7:0];
                            tx_start <= '1;
                        end
                    endcase
                // lê os regs 0 e 2
                end else if (read_enable) begin
                    case (address)
                        2'd0: data_out <= {16'd0, reg0_config};  // concatena para 32bits
                        2'd2: begin
                            data_out <= {24'd0, reg2_data_rx}; // concatena para 32bits
                            data_available_rx <= '0;
                        end 
                        default: data_out <= 32'd0;
                    endcase
                end
            end
            // independente do chip_select
            if (~txd)
                tx_start <= '0;
            data_available_flag <= ~reg0_config[12] && data_available_rx;
            ready_to_transmit_flag <= ~reg0_config[13] && ready_to_transmit_tx;
            irq <= data_available_flag || ready_to_transmit_flag;

            // escreve o reg0 com flags dos blocos e reg2 com data rx
            reg0_config[12] <= data_available_rx;
            reg0_config[13] <= ready_to_transmit_tx;
            // rx_error e sticky: fica em '1' ate o host ler o reg2 (dado recebido).
            // Sem isso, rx_error fica em '1' so durante o estado check_parity da FSM
            // (~1 ciclo de clock), impossibilitando leitura por polling de software.
            if (rx_error) begin
                reg0_config[14] <= 1'b1;
            end else if (chip_select && read_enable && address == 2'd2)
                reg0_config[14] <= 1'b0;
            reg0_config[15] <= tx_error;
            if(rx_done_rise) begin
                reg2_data_rx <= data_rx;
                data_available_rx <= '1;               
            end
            if(tx_done_rise) begin
                ready_to_transmit_tx <= '1;
            end else if(tx_start) begin
                ready_to_transmit_tx <= '0;
            end

        end
    end

    // mapeia os valores no registro 0 para portas de saida pra configurar os blocos
    uart_baud_rate_t baud_rate_conv;
    always_ff@(posedge clk) begin
        tx_done_prev <= tx_done;
        rx_done_prev <= rx_done;
        tx_done_rise <= tx_done && ~tx_done_prev;
        rx_done_rise <= rx_done && ~rx_done_prev;
        reg_reset <= reg0_config[0];
        parity_enable <= reg0_config[1];
        parity_type <= reg0_config[2];
        stop_bit <= reg0_config[3];
        data_len <= $unsigned(reg0_config[6:4] + 1);
        baud_rate <= baud_rate_conv;
    end

    // como o valor do baud_rate tá codificado nesse tipo com apenas 5 bits
    // esse case vai fazer a conversão pros labels do uart_baud_rate_t
    always_comb begin
        case (reg0_config[11:7])
            5'd0  : baud_rate_conv = UART_BAUD_50;
            5'd1  : baud_rate_conv = UART_BAUD_75;
            5'd2  : baud_rate_conv = UART_BAUD_110;
            5'd3  : baud_rate_conv = UART_BAUD_134;
            5'd4  : baud_rate_conv = UART_BAUD_150;
            5'd5  : baud_rate_conv = UART_BAUD_200;
            5'd6  : baud_rate_conv = UART_BAUD_300;
            5'd7  : baud_rate_conv = UART_BAUD_600;
            5'd8  : baud_rate_conv = UART_BAUD_1200;
            5'd9  : baud_rate_conv = UART_BAUD_1800;
            5'd10 : baud_rate_conv = UART_BAUD_2400;
            5'd11 : baud_rate_conv = UART_BAUD_4800;
            5'd12 : baud_rate_conv = UART_BAUD_9600;
            5'd13 : baud_rate_conv = UART_BAUD_14400;
            5'd14 : baud_rate_conv = UART_BAUD_19200;
            5'd15 : baud_rate_conv = UART_BAUD_28800;
            5'd16 : baud_rate_conv = UART_BAUD_31250;
            5'd17 : baud_rate_conv = UART_BAUD_38400;
            5'd18 : baud_rate_conv = UART_BAUD_56000;
            5'd19 : baud_rate_conv = UART_BAUD_57600;
            5'd20 : baud_rate_conv = UART_BAUD_76800;
            5'd21 : baud_rate_conv = UART_BAUD_115200;
            5'd22 : baud_rate_conv = UART_BAUD_128000;
            5'd23 : baud_rate_conv = UART_BAUD_153600;
            5'd24 : baud_rate_conv = UART_BAUD_230400;
            5'd25 : baud_rate_conv = UART_BAUD_256000;
            5'd26 : baud_rate_conv = UART_BAUD_460800;
            5'd27 : baud_rate_conv = UART_BAUD_500000;
            5'd28 : baud_rate_conv = UART_BAUD_576000;
            5'd29 : baud_rate_conv = UART_BAUD_921600;
            default: baud_rate_conv = UART_BAUD_115200;
        endcase
    end

    assign data_tx = reg1_data_tx;
endmodule