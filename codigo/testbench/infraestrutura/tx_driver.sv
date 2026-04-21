`ifndef TX_DRIVER_SV
`define TX_DRIVER_SV
`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
`include "uart_item.sv"

// Driver TX estendido com suporte a "test_mode":
//   - "default"   : configura CSR padrao (115200, 8 bits) e envia bytes.
//   - "baud_rate" : antes de cada item, reconfigura o CSR com a baud selecionada
//                   (item.baud_select indexa uma tabela de 6 baud rates) e so
//                   entao solicita a transmissao.
class tx_driver extends uvm_driver #(uart_item);
    `uvm_component_utils(tx_driver)

    virtual reg_if_bfm bfm_reg0;
    string test_mode = "default";

    function new(string name = "tx_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual reg_if_bfm)::get(this, "", "bfm_reg0", bfm_reg0))
            `uvm_fatal(get_full_name(), "BFM not set via uvm_config_db");
        void'(uvm_config_db#(string)::get(this, "", "test_mode", test_mode));
        `uvm_info(get_full_name(), $sformatf("tx_driver test_mode=%s", test_mode), UVM_LOW)
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        uart_item command;
        // Mapeamento baud_select -> indice CSR reg0_config[11:7]
        // 0:9600(12)  1:19200(14)  2:57600(19)  3:115200(21)
        // 4:230400(24) 5:460800(26)
        int unsigned baud_idx_tbl [6] = '{12, 14, 19, 21, 24, 26};
        int unsigned baud_bps_tbl [6] = '{9600, 19200, 57600, 115200, 230400, 460800};

        fork
            bfm_reg0.generate_clock(100_000_000, 0, 0);
            bfm_reg0.reset_pulse(1, 5, "Sync", 1);
            bfm_reg0.monitor_csr();
        join_any

        // Config inicial: 8 bits, sem paridade, 1 stop bit, 115200
        bfm_reg0.configure_csr(0, 0, 0, 0, 3'd7, 5'd21);
        bfm_reg0.get_csr();

        forever begin
            seq_item_port.get_next_item(command);

            case (test_mode)
                "baud_rate": begin
                    int unsigned sel     = command.baud_select % 6;
                    int unsigned baud_id = baud_idx_tbl[sel];
                    int unsigned bps     = baud_bps_tbl[sel];
                    `uvm_info(get_full_name(),
                        $sformatf("Reconfig CSR baud=%0d bps (csr_idx=%0d)", bps, baud_id), UVM_LOW)
                    repeat (50) @(posedge bfm_reg0.clk);
                    bfm_reg0.configure_csr(0, 0, 0, 0, 3'd7, baud_id[4:0]);
                    repeat (20) @(posedge bfm_reg0.clk);
                    bfm_reg0.get_csr();
                    bfm_reg0.uart_send(command.data);
                    // Aguarda conclusao da transmissao antes de liberar o proximo item.
                    // uart_send retorna apos escrever o registrador TX (nao-bloqueante);
                    // sem essa espera, o proximo configure_csr sobrescreve o baud rate
                    // enquanto o frame atual ainda esta sendo transmitido.
                    while (~bfm_reg0.ready_to_transmit)
                        @(posedge bfm_reg0.clk);
                end
                default: begin
                    bfm_reg0.uart_send(command.data);
                end
            endcase

            seq_item_port.item_done();
        end
    endtask : run_phase

endclass : tx_driver

`endif // TX_DRIVER_SV
