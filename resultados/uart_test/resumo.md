# Resultado — uart_test (Baseline)

**Veredicto:** PASS ✅  
**Data:** 2026-04-21

## Resumo do Report UVM

```
UVM_INFO  : 3018
UVM_ERROR :    0
UVM_FATAL :    0
```

## O que foi testado

Teste original fornecido com o exemplo de sala. Envia 500 bytes aleatórios via TX e 500 via RX simultaneamente. O scoreboard compara cada byte enviado com o recebido.

## Saída relevante (últimas verificações)

```
@ 52132015000 ns  rx_scb  MATCH: Expected command matches actual result.  [0x42 == 0x42]
@ 52195605000 ns  tx_scb  MATCH: Expected command matches actual result.  [0x26 == 0x26]
@ 52195705000 ns  rx_scb  TEST PASSED: All observed responses matched expected commands.
@ 52195705000 ns  tx_scb  TEST PASSED: All observed responses matched expected commands.
```

## Conclusão

Todos os 500 bytes de TX e 500 bytes de RX foram transmitidos e recebidos corretamente. Nenhum erro de comunicação.
