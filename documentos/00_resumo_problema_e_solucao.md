# Resumo — Problema e Implementação

**Disciplina:** SD242 — Sistemas Digitais  
**Atividade:** Avaliativa — Verificação UVM do Controlador UART  
**Prazo:** 22/04/2026 até às 12h  
**Entrega:** Formulário em cidigitalinatel.taplink.site

---

## 1. O que o Enunciado Pede

O enunciado parte do ambiente de verificação UVM do controlador UART estudado em sala e faz três exigências:

### 1.1 Criar dois novos casos de teste independentes

Os testes devem avaliar **outros elementos que não o byte transmitido/recebido** (já coberto pelo `uart_test` original). O enunciado sugere explicitamente:

- Variação de **baud rate**
- Inserção e detecção de **erro de paridade**

### 1.2 Erros identificados devem ser reportados

Se erros ocorrerem na simulação, o aluno deve **localizar a causa** e **documentar o problema** junto ao material entregue.

### 1.3 Ponto de partida: o código exemplo

O aluno deve **estender** o exemplo dado em sala, não reescrever do zero. A arquitetura UVM existente (dois agentes TX/RX, dois BFMs, scoreboard, coverage, environment) deve ser reutilizada e estendida conforme necessário.

---

## 2. O que foi Implementado

### 2.1 Teste 1 — Variação de Baud Rate (`uart_baud_rate_test`)

**Objetivo:** Verificar se o controlador UART transmite corretamente em 6 taxas de baud diferentes.

**Taxas testadas:** 9600, 19200, 57600, 115200, 230400 e 460800 bps.

**Como funciona:**

1. A sequence `baud_rate_sequence.sv` gera 6 itens, um para cada baud rate.
2. O `tx_driver` (modo `"baud_rate"`) reconfigura o CSR via `configure_csr()` antes de cada transmissão, escolhendo o índice correto no registrador `reg0_config[11:7]`.
3. O `scoreboard_baud.sv` monitora o sinal `txd` e mede a **largura real de cada bit** usando o timestamp das transições. Compara com o valor esperado (`1 / baud_rate` segundos) dentro de uma tolerância de ±1%.

**Arquivos novos/modificados:**

| Arquivo | Papel |
|---------|-------|
| `sequencias/baud_rate_sequence.sv` | Gera os 6 itens com `baud_select = 0..5` |
| `testes/uart_baud_rate_test.sv` | Define o teste, ativa modo `"baud_rate"` no config_db |
| `scoreboards/scoreboard_baud.sv` | Mede a largura de bit no TXD e valida |
| `infraestrutura/tx_driver.sv` | Estendido com modo `"baud_rate"`: configura CSR + wait loop |
| `infraestrutura/environment.sv` | Instancia `scoreboard_baud` quando `test_mode="baud_rate"` |

**Resultado:** PASS — todas as 6 baud rates validadas ✅

---

### 2.2 Teste 2 — Injeção e Detecção de Erro de Paridade (`uart_parity_error_test`)

**Objetivo:** Verificar se o controlador UART detecta corretamente erros de paridade no caminho RX.

**Como funciona:**

1. O CSR é configurado com paridade habilitada (`parity_enable=1`, `parity_type=1` para "even" no DUT).
2. A sequence `parity_error_sequence.sv` gera 10 itens:
   - Itens 1–5: `inject_parity_error=0` → paridade correta → `rx_error` esperado = 0
   - Itens 6–10: `inject_parity_error=1` → paridade invertida → `rx_error` esperado = 1
3. O `rx_driver` (modo `"parity"`) envia cada frame via `uart_bfm.send()` passando o flag `inject_parity_error`, que inverte o bit de paridade quando ativo.
4. O `scoreboard_parity.sv` aguarda o IRQ de `rx_done` após cada frame, espera o `monitor_csr` ler o registrador e atualizar `bfm_reg0.rx_error`, e compara com o valor esperado.

**Arquivos novos/modificados:**

| Arquivo | Papel |
|---------|-------|
| `sequencias/parity_error_sequence.sv` | 10 itens alternando `inject_parity_error` |
| `testes/uart_parity_error_test.sv` | Define o teste, configura CSR com paridade |
| `scoreboards/scoreboard_parity.sv` | Aguarda IRQ, amostra `bfm_reg0.rx_error` |
| `infraestrutura/rx_driver.sv` | Estendido com modo `"parity"`: chama `send()` com inject |
| `infraestrutura/uart_bfm.sv` | Task `send()` estendida com parâmetro `inject_parity_error` |
| `infraestrutura/uart_item.sv` | Novos campos: `inject_parity_error`, `parity_type`, `baud_select` |
| `rtl/reg_bank.sv` | Bit 14 (rx_error) transformado em sticky register |

**Resultado:** PASS — todos os 10 frames verificados corretamente ✅

---

## 3. Erros Encontrados e Reportados

Durante o desenvolvimento, 5 bugs foram identificados e corrigidos — conforme exigido pelo enunciado.

### Bug 1 — `uart_send` não-bloqueante quebrava medição de baud rate

**Onde:** `reg_if_bfm.sv` (task `uart_send`) + `tx_driver.sv`  
**Sintoma:** 9600 bps era medido como 19200 bps.  
**Causa:** `uart_send()` retorna imediatamente após escrever o registrador TX, sem aguardar o fim da transmissão. O próximo `configure_csr()` reconfigurava o `clock_div` enquanto o frame anterior ainda estava sendo transmitido.  
**Correção:** Adicionado wait loop em `tx_driver.sv` aguardando `ready_to_transmit=1` (sinalizado pelo `tx_done_rise` no `reg_bank`) antes de processar o próximo item.

```systemverilog
bfm_reg0.uart_send(command.data);
while (~bfm_reg0.ready_to_transmit)
    @(posedge bfm_reg0.clk);
```

---

### Bug 2 — Convenção de `parity_type` invertida no DUT

**Onde:** `rx_uart.sv` vs `uart_bfm.sv`  
**Sintoma:** Com `parity_type=0` e `inject_parity_error=1`, nenhum erro era detectado.  
**Causa:** O DUT usa `parity_type=0` → `~^datard` (ímpar), mas o BFM considera "even" = `^data`. Com `inject_parity_error=1`, o BFM enviava `~^data` (ímpar), que coincidia exatamente com o que o DUT esperava — a injeção de erro se cancelava.  
**Correção:** Teste configurado com `parity_type=1` (DUT usa `^datard` = par padrão, alinhado ao BFM "even").

---

### Bug 3 — `rx_error` transiente: FSM apaga o erro antes de `rx_done`

**Onde:** `rx_uart.sv` (FSM do receptor)  
**Sintoma:** `rx_error` nunca aparecia no registrador, mesmo com paridade errada injetada.  
**Causa:** A FSM usa `always@(*)` com latches implícitos. O sinal `rx_error=1` só existe durante o estado `check_parity`. No estado seguinte (`check_first_stop`), se o stop bit for válido, `rx_error` é zerado. O `reg_bank` original replicava esse sinal diretamente: `reg0_config[14] <= rx_error` — tornando a flag impossível de capturar por polling.  
**Correção:** Bit 14 de `reg_bank.sv` transformado em **sticky register**: seta quando `rx_error=1`, limpa apenas quando reg2 é lido.

```systemverilog
if (rx_error)
    reg0_config[14] <= 1'b1;
else if (chip_select && read_enable && address == 2'd2)
    reg0_config[14] <= 1'b0;
```

---

### Bug 4 — Sticky bit limpo pelo `rx_monitor` antes do scoreboard ler

**Onde:** `rx_monitor.sv` + `scoreboard_parity.sv`  
**Sintoma:** Mesmo com o sticky bit, o scoreboard via `#300us + read_register(reg0)` sempre lia `rx_error=0`.  
**Causa:** O `rx_monitor.result_monitor_task()` chama `uart_receive()` que lê reg2 após cada frame, acionando a limpeza do sticky bit antes do scoreboard chegar a ler reg0.  
**Correção:** Scoreboard reescrito para usar `@(posedge irq)` (síncrono com `rx_done`) e amostrar `bfm_reg0.rx_error` — variável já atualizada pelo `monitor_csr` na mesma borda de IRQ, antes de `uart_receive` limpar o sticky.

```systemverilog
@(posedge bfm_reg0.irq);
repeat(5) @(posedge bfm_reg0.clk);  // monitor_csr completa em 3 ciclos
observed_err = bfm_reg0.rx_error;
```

---

## 4. Resumo de Resultados

| Teste | Itens verificados | Erros UVM | Veredicto |
|-------|-------------------|-----------|-----------|
| `uart_test` (baseline, não modificado) | 500 TX + 500 RX bytes aleatórios | 0 | **PASS** ✅ |
| `uart_baud_rate_test` | 6 baud rates (9600 → 460800 bps) | 0 | **PASS** ✅ |
| `uart_parity_error_test` | 10 frames (5 ok + 5 com erro injetado) | 0 | **PASS** ✅ |

Os logs completos de simulação estão em `resultados/<nome_do_teste>/simulate.log`.
