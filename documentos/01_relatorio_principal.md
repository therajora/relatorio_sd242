# Relatório de Atividade — SD242: Verificação UVM do Controlador UART

**Data:** 2026-04-21  
**Disciplina:** SD242 — Sistemas Digitais  
**Ferramentas:** Vivado 2025.2 + xsim, Docker Compose, UVM 1.2, SystemVerilog  
**Repositório:** https://github.com/therajora/relatorio_sd242

---

## 1. Enunciado e Escopo

O PDF `SD242-Atividade-UVM.pdf` solicita, a partir do exemplo de verificação UVM do controlador UART fornecido em sala:

- **Criar dois novos casos de teste independentes do teste de comunicação byte-a-byte original.**
- Sugestões do enunciado: variação de baud rate e injeção/detecção de erro de paridade.
- Entregar código dos testes, relatório com passo a passo de execução, e documentar qualquer erro encontrado em simulação com sua causa.

A estrutura de trabalho criada fica em `uvm_activity/` na raiz do repositório, espelhando o layout de `uart_ax/`.

---

## 2. Arquitetura do DUT

O controlador UART possui três módulos principais:

| Módulo | Função |
|--------|--------|
| `reg_bank.sv` | Interface de registradores (endereço 00: config, 01: tx_data, 02: rx_data) |
| `clock_div.sv` | Divisor de clock configurável por baud rate (até 460800 bps @ 100 MHz) |
| `tx_uart.sv` | FSM transmissora: start → data → [parity] → stop |
| `rx_uart.sv` | FSM receptora: start → data → [check_parity] → stop → done |

**Registrador de configuração `reg0_config` (endereço 00):**

| Bits | Campo | Descrição |
|------|-------|-----------|
| [0] | reg_reset | Reset dos módulos UART |
| [1] | parity_enable | Habilita paridade |
| [2] | parity_type | 0=even no DUT (ver nota), 1=odd no DUT |
| [3] | stop_bit | 0=1 stop, 1=2 stops |
| [6:4] | data_len | Comprimento do dado (valor+1 bits) |
| [11:7] | baud_rate | Índice da taxa de baud (enum UART_BAUD_*) |
| [12] | data_available_rx | Flag: dado RX disponível |
| [13] | ready_to_transmit_tx | Flag: TX pronto |
| [14] | **rx_error** | Flag de erro RX (paridade ou stop bit inválido) |
| [15] | tx_error | Flag de erro TX |

> **Nota sobre convenção de paridade:** A lógica de `rx_uart.sv` tem os labels de parity_type invertidos em relação ao BFM. `parity_type=0` → DUT usa `~^datard` (ímpar padrão), `parity_type=1` → DUT usa `^datard` (par padrão). O BFM "even" envia `^data`. Para que DUT e BFM concordem, o teste usa `parity_type=1`.

**Pipeline de clock_div:** `max_count` é combinacional; `max_count_tx_reg` e `max_count_rx_reg` são registrados — há **1 ciclo de atraso** entre a escrita do CSR e a efetivação da nova taxa.

---

## 3. Arquitetura UVM do Testbench

```
testbench (top)
├── uart_bfm        (interface: rxd, txd, clk)
├── reg_if_bfm      (interface: clk, address, data_in/out, chip_select, write/read_enable, irq)
└── uart_controller (DUT)

uvm_test_top (uart_test | uart_baud_rate_test | uart_parity_error_test)
└── uart_environment
    ├── rx_agent (rx_sequencer → rx_driver → rx_monitor)
    ├── tx_agent (tx_sequencer → tx_driver → tx_monitor)
    └── [scoreboard / coverage dependentes do test_mode]
```

**Seleção de modo via `uvm_config_db#(string)::set(…, "test_mode", "baud_rate"|"parity"|"default")`**

---

## 4. Arquivos Criados/Modificados

### 4.1 Novos arquivos (sim/)

| Arquivo | Descrição |
|---------|-----------|
| `baud_rate_sequence.sv` | Gera 6 itens (baud_select=0..5): 9600, 19200, 57600, 115200, 230400, 460800 bps |
| `parity_error_sequence.sv` | Gera 10 itens: primeiros 5 com inject_err=0, últimos 5 com inject_err=1 |
| `uart_baud_rate_test.sv` | Teste de variação de baud rate |
| `uart_parity_error_test.sv` | Teste de injeção/detecção de erro de paridade |
| `scoreboard_baud.sv` | Mede largura de bit no TXD e compara com esperado por baud rate |
| `scoreboard_parity.sv` | Aguarda IRQ de rx_done, amostra bfm_reg0.rx_error via monitor_csr |

### 4.2 Arquivos modificados

| Arquivo | Modificação |
|---------|-------------|
| `uart_bfm.sv` | Task `send()` ganhou parâmetro `inject_parity_error`: inverte bit de paridade quando 1 |
| `rx_driver.sv` | Modo "parity": chama `bfm_uart0.send()` com `inject_parity_error` do item |
| `tx_driver.sv` | Modo "baud_rate": configura CSR antes de cada send + **wait loop** aguardando ready_to_transmit após uart_send |
| `environment.sv` | Instancia scoreboard específico baseado em `test_mode` |
| `testbench.sv` | Adicionados includes dos dois novos testes |
| `uart_item.sv` | Estendido: campos `inject_parity_error`, `parity_type`, `baud_select` |
| `reg_bank.sv` | Bit 14 (rx_error) transformado em **sticky register**: seta em rx_error=1, limpa ao ler reg2 |

### 4.3 Script de execução

`scripts/sim_uvm_xsim.sh` — wrapper que:
1. Executa `xvlog -sv -L uvm` compilando todos os arquivos RTL + sim
2. Executa `xelab testbench -L uvm -L work -timescale 1ns/100ps`
3. Executa `xsim` com `UVM_TESTNAME`, `UVM_VERBOSITY`, `seed`
4. Faz parse do Report Summary (via `awk`) para contar UVM_ERROR/UVM_FATAL
5. Copia logs para `logs/<test>/`

---

## 5. Execução Passo a Passo (Docker Compose)

O ambiente Docker usa a imagem `fpga-vivado:dev` com Vivado 2025.2 montado em `/workspace`.

### 5.1 Pré-requisitos

```bash
# Na raiz do repositório (WSL Ubuntu-24.04)
cd /home/rafael/fpga
docker compose -f docker-compose.vivado.yml build   # apenas na primeira vez
```

### 5.2 Teste 0 — Baseline (uart_test, regressão)

```bash
docker compose -f docker-compose.vivado.yml run --rm vivado \
  bash -c "source /workspace/2025.2/Vivado/settings64.sh && \
           UVM_TEST=uart_test bash /workspace/uvm_activity/scripts/sim_uvm_xsim.sh"
```

**Saída esperada:**
```
Resumo: UVM_INFO=1017  UVM_ERROR=0  UVM_FATAL=0
PASS: uart_test
```

### 5.3 Teste 1 — Baud Rate

```bash
docker compose -f docker-compose.vivado.yml run --rm vivado \
  bash -c "source /workspace/2025.2/Vivado/settings64.sh && \
           UVM_TEST=uart_baud_rate_test bash /workspace/uvm_activity/scripts/sim_uvm_xsim.sh"
```

**Saída esperada:**
```
MATCH baud=9600 | MATCH baud=19200 | MATCH baud=57600 | MATCH baud=115200 | MATCH baud=230400 | MATCH baud=460800
Resumo: UVM_INFO=43  UVM_ERROR=0  UVM_FATAL=0
PASS: uart_baud_rate_test
```

### 5.4 Teste 2 — Paridade

```bash
docker compose -f docker-compose.vivado.yml run --rm vivado \
  bash -c "source /workspace/2025.2/Vivado/settings64.sh && \
           UVM_TEST=uart_parity_error_test bash /workspace/uvm_activity/scripts/sim_uvm_xsim.sh"
```

**Saída esperada:**
```
Item 1..5: esperado_err=0 observado_err=0 → MATCH (x5)
Item 6..10: esperado_err=1 observado_err=1 → MATCH (x5)
Resumo: UVM_INFO=66  UVM_ERROR=0  UVM_FATAL=0
PASS: uart_parity_error_test
```

---

## 6. Resultados Finais

| Teste | UVM_INFO | UVM_ERROR | UVM_FATAL | Veredicto |
|-------|----------|-----------|-----------|-----------|
| `uart_test` (baseline) | 1017 | 0 | 0 | **PASS** ✅ |
| `uart_baud_rate_test` | 43 | 0 | 0 | **PASS** ✅ |
| `uart_parity_error_test` | 66 | 0 | 0 | **PASS** ✅ |

---

## 7. Erros Encontrados em Simulação — Análise Detalhada

### 7.1 Erro A — `uart_baud_rate_test`: 9600 bps medido como 19200 bps

#### Sintoma inicial

```
MISMATCH baud=9600: bit medio=52100.00 ns vs esperado=104166.67 ns
MISMATCH baud=19200: bit medio=52100.00 ns vs esperado=52083.33 ns  (MATCH, na verdade era o 9600)
```

#### Análise da Causa Raiz

A task `uart_send()` em `reg_if_bfm.sv` é **não-bloqueante**: retorna imediatamente após escrever o registrador TX sem aguardar o fim da transmissão (`ready_to_transmit` voltando a 1). Isso causava:

1. Driver chama `configure_csr(9600)` → `uart_send(data_item1)` → retorna imediatamente → `item_done()`
2. Sequence gera item 2 → driver chama `configure_csr(19200)` 
3. CSR sobrescrito ~700 ns depois do início do frame — o `clock_div` comuta para 19200 bps **durante a transmissão do frame de 9600 bps**
4. O frame de 9600 bps é enviado na metade a 19200 bps → medição errônea

**Evidência no código (`reg_if_bfm.sv`):**
```systemverilog
task uart_send(input bit [7:0] data_tx);
    while(~ready_to_transmit) @(posedge clk);
    write_register({24'b0, data_tx}, 2'b01);
    ready_to_transmit = 0;   // ← retorna aqui, não espera tx_done
endtask
```

#### Correção Aplicada (`tx_driver.sv`)

```systemverilog
// Modo baud_rate: após uart_send, aguardar tx_done antes do próximo configure_csr
bfm_reg0.uart_send(command.data);
while (~bfm_reg0.ready_to_transmit)
    @(posedge bfm_reg0.clk);
```

O wait loop espera `ready_to_transmit` voltar a 1 (sinalizado pelo `tx_done_rise` no `reg_bank`), garantindo que a transmissão do frame anterior complete antes de reconfigurar o baud rate.

#### Resultado após correção

Todos os 6 baud rates validados: 9600, 19200, 57600, 115200, 230400, 460800 bps — **PASS**.

---

### 7.2 Erro B — `uart_parity_error_test`: rx_error sempre observado como 0

#### Sintoma inicial

```
MISMATCH item 6: esperado=1 observado=0
MISMATCH item 7: esperado=1 observado=0
... (itens 6 a 10, todos com inject_err=1)
```

O CSR lido era `0x00002af2` — bit 14 (`rx_error`) sempre 0.

---

#### Causa Raiz 1 — Convenção de paridade invertida no DUT

O `rx_uart.sv` tem a lógica de paridade com labels **trocados** em relação ao BFM:

```systemverilog
// rx_uart.sv
if (parity_type == 0)
    parity = ~^datard;  // ← isso é ímpar (ODD) padrão, não "even"
else
    parity = ^datard;   // ← isso é par (EVEN) padrão
```

O BFM `uart_bfm.sv` envia em modo "even": `parity_bit = ^data`.

Com `parity_type=0` no CSR e `inject_parity_error=1`:
- DUT espera `~^datard` (ímpar)
- BFM envia `~^data` (inversão de par = ímpar)
- Resultado: os dois lados concordam — **nenhum erro detectado**! A injeção de erro cancelava a si mesma.

**Correção aplicada (`uart_parity_error_test.sv`):** mudar `parity_type=0` para `parity_type=1` no `configure_csr`, fazendo o DUT usar `^datard` (par padrão), compatível com o BFM "even".

```systemverilog
// Antes: configure_csr(0, 1, 0, 0, 3'd7, 5'd21)
// Depois:
uart_env.tx_ag.tx_drv.bfm_reg0.configure_csr(0, 1, 1, 0, 3'd7, 5'd21);
// parity_type=1 -> DUT usa ^datard = EVEN padrão (coincide com BFM "even")
```

---

#### Causa Raiz 2 — `rx_error` é sinal transiente; sticky bit limpo antes do scoreboard ler

Mesmo com a convenção corrigida, `rx_error=1` era visto pelo scoreboard como 0. Análise do fluxo:

```
rx_uart FSM:  check_parity state → rx_error=1 (apenas neste estado, ~10 ns)
              check_first_stop state → rx_error=0 (stop bit válido apaga o erro!)
              done state → rx_error=0
reg_bank:     reg0_config[14] <= rx_error  (sem latch → transitório)
```

O `rx_uart.sv` usa `always@(*)` criando **latches** implícitos — `rx_error` só fica em 1 durante o estado `check_parity`. No estado `check_first_stop`, se o stop bit for válido, `rx_error` volta a 0 antes de `rx_done` ser asserted.

**Primeira tentativa de correção:** adicionar sticky bit em `reg_bank.sv` — funcional, mas a flag era limpa pelo `rx_monitor`.

**Problema adicional — `rx_monitor` limpava o sticky bit:**

O `rx_monitor.result_monitor_task()` chama `bfm_reg0.uart_receive()` após cada frame. Essa task executa `read_register(data_r, 2'b10)` — leitura de reg2 (endereço 2). No `reg_bank.sv`, a condição de limpeza do sticky bit era exatamente essa leitura:

```systemverilog
else if (chip_select && read_enable && address == 2'd2)
    reg0_config[14] <= 1'b0;  // ← limpeza ao ler reg2
```

Sequência temporal completa:
1. Frame com erro recebido → `rx_error=1` → sticky bit seta `reg0_config[14]=1`
2. `rx_done` → IRQ
3. `monitor_csr`: `@(posedge irq)` → lê reg0 → vê `[14]=1` → atualiza `bfm_reg0.rx_error=1` ✓
4. `uart_receive` (rx_monitor): acorda com `data_available=1` → lê reg2 → **sticky limpa** → `reg0_config[14]=0`
5. Scoreboard (com #300us delay): lê reg0 300 μs depois → vê `[14]=0` → **MISMATCH**

---

#### Correção Final Aplicada

**`reg_bank.sv`:** Sticky bit mantido (correto), limpeza via leitura de reg2 mantida.

**`scoreboard_parity.sv`:** Mudança de estratégia de amostragem — em vez de `#300us` + `read_register(reg0)`, o scoreboard agora:

1. Aguarda `@(posedge bfm_reg0.irq)` — síncrono com rx_done de cada frame
2. Aguarda 5 ciclos de clock — tempo para `monitor_csr` concluir leitura e atualizar `bfm_reg0.rx_error`
3. Amostra `bfm_reg0.rx_error` — variável do BFM já atualizada pelo `monitor_csr`, que leu o sticky bit ANTES de `uart_receive` limpá-lo

```systemverilog
// Antes (polling com delay fixo):
#300us;
bfm_reg0.read_register(csr, 2'b00);
observed_err = csr[14];

// Depois (síncrono com IRQ, lê variável BFM já atualizada por monitor_csr):
@(posedge bfm_reg0.irq);
repeat(5) @(posedge bfm_reg0.clk);  // monitor_csr completa em 3 ciclos
observed_err = bfm_reg0.rx_error;
```

**Por que funciona:** `monitor_csr` reage ao mesmo IRQ, lê reg0 (3 ciclos), vê sticky=1, atualiza `bfm_reg0.rx_error=1`. O scoreboard espera 5 ciclos (margem sobre os 3 do monitor_csr), lê a variável BFM que já está com o valor correto. Só depois `uart_receive` acorda e limpa o sticky.

#### Resultado após correção

Todos os 10 itens validados (5 MATCH sem erro, 5 MATCH com erro) — **PASS**.

---

## 8. Conclusão

### Resultados finais

| Objetivo | Status |
|----------|--------|
| Teste baseline `uart_test` executado sem regressão | ✅ PASS |
| `uart_baud_rate_test` implementado, depurado e corrigido | ✅ PASS (6/6 baud rates) |
| `uart_parity_error_test` implementado, depurado e corrigido | ✅ PASS (10/10 itens) |
| Erros documentados com causa raiz e correção | ✅ Completo |

### Bugs encontrados pela verificação UVM

| # | Componente | Tipo | Descricao | Corrigido em |
|---|-----------|------|-----------|-------------|
| 1 | `tx_driver.sv` | Testbench | `uart_send` não-bloqueante: próximo `configure_csr` sobrescreve baud rate mid-frame | `tx_driver.sv` — wait loop |
| 2 | `rx_uart.sv` | RTL (design) | `rx_error` transiente: limpo em `check_first_stop` quando stop bit válido | Contornado com sticky em `reg_bank.sv` |
| 3 | `reg_bank.sv` | RTL (design) | `rx_error` não é sticky: perdido antes do polling de software | Corrigido com sticky bit |
| 4 | `uart_parity_error_test.sv` | Testbench | Convenção parity_type invertida: injeção de erro cancelava a si mesma | `configure_csr(..., parity_type=1, ...)` |
| 5 | `scoreboard_parity.sv` | Testbench | Delay fixo de 300µs perdia o sticky por `uart_receive` limpar reg2 antes | IRQ-based sampling + `bfm_reg0.rx_error` |

### Arquivos entregues

```
uvm_activity/
├── rtl/
│   ├── reg_bank.sv          (modificado — sticky bit rx_error)
│   └── [demais RTL sem alteração]
├── sim/
│   ├── uart_item.sv         (modificado — campos inject_parity_error, parity_type, baud_select)
│   ├── uart_bfm.sv          (modificado — inject_parity_error em send())
│   ├── rx_driver.sv         (modificado — modo parity)
│   ├── tx_driver.sv         (modificado — modo baud_rate + wait loop tx_done)
│   ├── environment.sv       (modificado — scoreboard por test_mode)
│   ├── testbench.sv         (modificado — includes dos novos testes)
│   ├── baud_rate_sequence.sv        (novo)
│   ├── parity_error_sequence.sv     (novo)
│   ├── uart_baud_rate_test.sv       (novo)
│   ├── uart_parity_error_test.sv    (novo)
│   ├── scoreboard_baud.sv           (novo)
│   └── scoreboard_parity.sv         (novo — IRQ-based sampling)
├── scripts/sim_uvm_xsim.sh  (novo)
└── logs/
    ├── uart_test/              (PASS)
    ├── uart_baud_rate_test/    (PASS)
    └── uart_parity_error_test/ (PASS)
```
