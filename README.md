# SD242 — Atividade de Verificação UVM: Controlador UART

**Disciplina:** SD242 — Sistemas Digitais  
**Data:** 2026-04-21  
**Ferramentas:** Vivado 2025.2 · xsim · Docker · UVM 1.2 · SystemVerilog  
**Repositório:** https://github.com/therajora/relatorio_sd242

---

## Resultado Geral

| Teste | Items verificados | UVM_ERROR | Veredicto |
|-------|-------------------|-----------|-----------|
| `uart_test` | 500 TX + 500 RX bytes | 0 | **PASS** ✅ |
| `uart_baud_rate_test` | 6 baud rates | 0 | **PASS** ✅ |
| `uart_parity_error_test` | 10 frames (5 ok + 5 erro) | 0 | **PASS** ✅ |

---

## Estrutura desta pasta

```
relatorio_sd242/
│
├── README.md                          ← este arquivo
│
├── documentos/
│   ├── 01_relatorio_principal.md      ← relatório completo com análise de bugs
│   ├── 02_ambiente_simulacao.md       ← justificativa e guia do ambiente Docker
│   └── 03_enunciado_exercicio.pdf     ← enunciado original da atividade
│
├── codigo/
│   ├── rtl/                           ← módulos RTL do controlador UART
│   │   ├── baud_rate_type.svh         (enum dos baud rates)
│   │   ├── clock_div.sv               (divisor de clock)
│   │   ├── reg_bank.sv                (registradores — MODIFICADO: sticky rx_error)
│   │   ├── rx_uart.sv                 (FSM receptora)
│   │   ├── tx_uart.sv                 (FSM transmissora)
│   │   └── uart_controller.sv         (top-level do DUT)
│   │
│   └── testbench/
│       ├── infraestrutura/            ← BFMs, agents, drivers, monitors
│       │   ├── uart_bfm.sv            (BFM do barramento UART — MODIFICADO: inject_parity_error)
│       │   ├── reg_if_bfm.sv          (BFM da interface de registradores)
│       │   ├── uart_item.sv           (transaction object — MODIFICADO: novos campos)
│       │   ├── transaction.sv
│       │   ├── environment.sv         (MODIFICADO: scoreboard por test_mode)
│       │   ├── testbench.sv           (MODIFICADO: includes dos novos testes)
│       │   ├── coverage.sv
│       │   ├── rx_agent.sv / rx_driver.sv / rx_monitor.sv / rx_sequencer.sv
│       │   └── tx_agent.sv / tx_driver.sv / tx_monitor.sv / tx_sequencer.sv
│       │                               (tx_driver MODIFICADO: wait loop tx_done)
│       │                               (rx_driver MODIFICADO: modo parity)
│       │
│       ├── sequencias/                ← sequences UVM
│       │   ├── baud_rate_sequence.sv  (NOVO: 6 baud rates)
│       │   ├── parity_error_sequence.sv (NOVO: 10 frames com/sem erro)
│       │   ├── incremental_sequence.sv
│       │   └── random_sequence.sv
│       │
│       ├── scoreboards/               ← verificação de resultados
│       │   ├── scoreboard.sv          (baseline: compara bytes RX/TX)
│       │   ├── scoreboard_baud.sv     (NOVO: mede largura de bit no TXD)
│       │   └── scoreboard_parity.sv   (NOVO: verifica rx_error via IRQ)
│       │
│       └── testes/                    ← uvm_test top-level
│           ├── test.sv                (uart_test — baseline)
│           ├── uart_baud_rate_test.sv (NOVO)
│           └── uart_parity_error_test.sv (NOVO)
│
├── resultados/
│   ├── uart_test/
│   │   ├── resumo.md                  ← resumo do resultado
│   │   └── simulate.log               ← log completo do xsim
│   ├── uart_baud_rate_test/
│   │   ├── resumo.md
│   │   └── simulate.log
│   └── uart_parity_error_test/
│       ├── resumo.md
│       └── simulate.log
│
└── scripts/
    └── sim_uvm_xsim.sh                ← script de compilação e simulação
```

---

## Como executar

O código fonte que roda está em `../uvm_activity/`. Os arquivos em `codigo/` são cópias organizadas para leitura e entrega.

### Opção 1 — Docker (ambiente local, via `sim_uvm_xsim.sh`)

A partir da raiz do repositório (`/home/rafael/fpga`):

```bash
# Teste baseline
docker compose -f docker-compose.vivado.yml run --rm vivado \
  bash -c 'source /workspace/2025.2/Vivado/settings64.sh && \
           UVM_TEST=uart_test bash /workspace/uvm_activity/scripts/sim_uvm_xsim.sh'

# Teste de baud rate
docker compose -f docker-compose.vivado.yml run --rm vivado \
  bash -c 'source /workspace/2025.2/Vivado/settings64.sh && \
           UVM_TEST=uart_baud_rate_test bash /workspace/uvm_activity/scripts/sim_uvm_xsim.sh'

# Teste de paridade
docker compose -f docker-compose.vivado.yml run --rm vivado \
  bash -c 'source /workspace/2025.2/Vivado/settings64.sh && \
           UVM_TEST=uart_parity_error_test bash /workspace/uvm_activity/scripts/sim_uvm_xsim.sh'
```

### Opção 2 — Cluster / Vivado TCL (ambiente do laboratório, via `run.tcl`)

No terminal do cluster com Vivado disponível, dentro da pasta `uvm_activity/`:

```tcl
vivado -mode tcl
cd <caminho>/uvm_activity
# Selecionar o teste desejado (editar config.tcl ou sobrescrever a variável):
set UVM_TEST "uart_baud_rate_test"   ;# ou uart_test / uart_parity_error_test
source run.tcl
```

Para rodar com GUI e ver formas de onda:

```tcl
set GUI_MODE "gui"
set UVM_TEST "uart_parity_error_test"
source run.tcl
# O wave.tcl é carregado automaticamente e configura os sinais no viewer
```

> Os scripts `config.tcl`, `run.tcl` e `wave.tcl` foram desenvolvidos pelo professor e adaptados para incluir todos os arquivos dos novos testes.

Para detalhes sobre o ambiente Docker e como reproduzir, ver `documentos/02_ambiente_simulacao.md`.

---

## Bugs encontrados pela verificação

| # | Local | Tipo | Descrição |
|---|-------|------|-----------|
| 1 | `tx_driver.sv` | Testbench | `uart_send` não-bloqueante: configure_csr do próximo item sobrescreve baud rate mid-frame |
| 2 | `rx_uart.sv` | RTL | `rx_error` transiente: FSM apaga o erro no estado `check_first_stop` antes de `rx_done` |
| 3 | `reg_bank.sv` | RTL | `rx_error` não era sticky: perdido por polling antes de software ler |
| 4 | `uart_parity_error_test.sv` | Testbench | Convenção `parity_type` invertida: injeção de erro se cancelava com a detecção do DUT |
| 5 | `scoreboard_parity.sv` | Testbench | Delay fixo de 300 µs perdia o sticky (limpo por `uart_receive` → reg2 read) |
