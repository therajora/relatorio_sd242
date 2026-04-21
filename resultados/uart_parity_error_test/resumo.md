# Resultado — uart_parity_error_test

**Veredicto:** PASS ✅  
**Data:** 2026-04-21

## Resumo do Report UVM

```
UVM_INFO  : 66
UVM_ERROR :  0
UVM_FATAL :  0
```

## O que foi testado

Injeção e detecção de erro de paridade. 10 frames enviados via RX (uart_bfm → rxd):
- Itens 1–5: paridade correta (`inject_parity_error=0`) → rx_error esperado = 0
- Itens 6–10: paridade invertida (`inject_parity_error=1`) → rx_error esperado = 1

## Saída do Scoreboard

```
@ 105995000 ns    Item 1: esperado_err=0 observado_err=0   MATCH
@ 219115000 ns    Item 2: esperado_err=0 observado_err=0   MATCH
@ 331675000 ns    Item 3: esperado_err=0 observado_err=0   MATCH
@ 444795000 ns    Item 4: esperado_err=0 observado_err=0   MATCH
@ 557915000 ns    Item 5: esperado_err=0 observado_err=0   MATCH
@ 671035000 ns    Item 6: esperado_err=1 observado_err=1   MATCH
@ 783595000 ns    Item 7: esperado_err=1 observado_err=1   MATCH
@ 896715000 ns    Item 8: esperado_err=1 observado_err=1   MATCH
@ 1009835000 ns   Item 9: esperado_err=1 observado_err=1   MATCH
@ 1122955000 ns   Item 10: esperado_err=1 observado_err=1  MATCH

TEST PASSED: flag rx_error consistente com injecoes.
```

## Bugs encontrados e corrigidos

### Bug 1 — Convenção de paridade invertida no DUT
`parity_type=0` no RTL usa `~^datard` (ímpar), não par. Com `inject_parity_error=1`, a inversão do BFM cancelava a detecção.  
**Correção:** `configure_csr(..., parity_type=1, ...)` no teste.

### Bug 2 — `rx_error` transiente no FSM de rx_uart
O sinal `rx_error` só fica em 1 durante o estado `check_parity` (~10 ns). O estado `check_first_stop` apaga o erro se o stop bit for válido.  
**Correção:** bit 14 de `reg_bank.sv` transformado em sticky register.

### Bug 3 — Sticky bit limpo antes do scoreboard ler
O `rx_monitor` chama `uart_receive()` que lê reg2, acionando a limpeza do sticky bit antes do scoreboard ler reg0.  
**Correção:** scoreboard reescrito para aguardar o IRQ de `rx_done` e amostrar `bfm_reg0.rx_error` (variável já atualizada por `monitor_csr` antes de `uart_receive` limpar o sticky).
