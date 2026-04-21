# Resultado — uart_baud_rate_test

**Veredicto:** PASS ✅  
**Data:** 2026-04-21

## Resumo do Report UVM

```
UVM_INFO  : 43
UVM_ERROR :  0
UVM_FATAL :  0
```

## O que foi testado

Validação de 6 baud rates diferentes: 9600, 19200, 57600, 115200, 230400 e 460800 bps. O scoreboard mede a largura de bit real no sinal TXD e compara com o esperado (1/baud_rate), dentro de uma tolerância de ±1%.

## Saída do Scoreboard

```
@ 208425000 ns    MATCH baud=9600
@ 729325000 ns    MATCH baud=19200
@ 937685000 ns    MATCH baud=57600
@ 1406545000 ns   MATCH baud=115200
@ 1510745000 ns   MATCH baud=230400
@ 1667045000 ns   MATCH baud=460800

TEST PASSED: todas as baud rates validadas.
```

## Bug encontrado e corrigido

**Causa:** `uart_send()` em `reg_if_bfm.sv` é não-bloqueante — retorna após escrever o registrador TX sem aguardar o fim da transmissão. O próximo `configure_csr()` sobrescrevia o baud rate do `clock_div` enquanto o frame anterior ainda estava sendo transmitido.

**Correção em `tx_driver.sv`:**
```systemverilog
bfm_reg0.uart_send(command.data);
// Aguarda tx_done (ready_to_transmit volta a 1) antes do próximo configure_csr
while (~bfm_reg0.ready_to_transmit)
    @(posedge bfm_reg0.clk);
```
