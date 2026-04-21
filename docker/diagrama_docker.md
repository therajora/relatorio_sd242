# Diagrama — Como o Docker Compose funciona neste projeto

## Visão geral do fluxo

```
  Usuário
     │
     ├── make sim-baud          (headless)
     └── make sim-gui UVM_TEST=uart_baud_rate_test  (com janela)
     │
     ▼
┌─────────────────────────────────────────────────────┐
│  Makefile  (relatorio_sd242/Makefile)               │
│                                                     │
│  COMPOSE_FILE = docker/docker-compose.yml           │
│  SIM_SCRIPT  = /workspace/uvm_activity/scripts/...  │
│                                                     │
│  docker compose -f docker/docker-compose.yml        │
│    run --rm vivado bash -c "..."                    │
└─────────────────┬───────────────────────────────────┘
                  │ invoca
                  ▼
┌─────────────────────────────────────────────────────┐
│  docker-compose.yml  (relatorio_sd242/docker/)      │
│                                                     │
│  build:  context: .  /  dockerfile: Dockerfile      │
│                                                     │
│  volumes:                                           │
│    ../../          →  /workspace       (projeto)    │
│    ../../2025.2    →  /workspace/2025.2 (Vivado)    │
│    /tmp/.X11-unix  →  /tmp/.X11-unix   (GUI X11)   │
│    /mnt/wslg       →  /mnt/wslg        (WSLg)      │
│                                                     │
│  environment:                                       │
│    DISPLAY, WAYLAND_DISPLAY, XDG_RUNTIME_DIR        │
└──────┬──────────────────┬───────────────────────────┘
       │ build            │ monta volumes
       ▼                  ▼
┌─────────────┐   ┌────────────────────────────────────┐
│ Dockerfile  │   │  Container efêmero (--rm)          │
│             │   │                                    │
│ FROM        │   │  /workspace/                       │
│ almalinux:9 │   │  ├── uvm_activity/                 │
│             │   │  │   ├── rtl/  sim/  scripts/      │
│ instala:    │   │  │   └── wave.tcl                  │
│ gcc, make,  │   │  └── 2025.2/Vivado/               │
│ libX11,     │   │      ├── settings64.sh             │
│ python3,    │   │      └── bin/xvlog, xelab, xsim    │
│ ncurses...  │   │                                    │
│             │   │  /tmp/.X11-unix  (socket X11)      │
│ USER vivado │   │  /mnt/wslg       (socket WSLg)     │
└─────────────┘   └────────────────────────────────────┘
```

---

## Mapeamento de pastas: host → container

```
HOST (WSL /home/rafael/fpga/)          CONTAINER (/workspace/)
─────────────────────────────────      ──────────────────────────────────
relatorio_sd242/           ──────────► /workspace/relatorio_sd242/
uvm_activity/              ──────────► /workspace/uvm_activity/
│  ├── rtl/*.sv                          (código RTL do DUT)
│  ├── sim/*.sv                          (testbench UVM)
│  ├── scripts/sim_uvm_xsim.sh          (script de compilação)
│  └── wave.tcl                          (configuração de sinais GUI)
2025.2/Vivado/             ──────────► /workspace/2025.2/Vivado/
│  ├── settings64.sh                    (configura PATH dos binários)
│  └── bin/xvlog, xelab, xsim          (ferramentas de simulação)
/tmp/.X11-unix             ──────────► /tmp/.X11-unix
/mnt/wslg                  ──────────► /mnt/wslg
```

> O container não tem Vivado embutido — fica no host e é acessado via volume.
> O Dockerfile instala apenas as **dependências de sistema** (libs, compiladores).

---

## Modo headless vs modo GUI

```
make sim UVM_TEST=uart_baud_rate_test
     │
     └──► bash -c "source settings64.sh && UVM_TEST=... bash sim_uvm_xsim.sh"
               │
               ├─ xvlog  →  compila RTL + testbench
               ├─ xelab  →  elabora hierarquia → snapshot work.testbench
               └─ xsim --runall  →  simula → simulate.log → PASS/FAIL
                                                   (sem janela)


make sim-gui UVM_TEST=uart_baud_rate_test
     │
     ├─1─► make sim  (headless — garante snapshot compilado)
     │         └─ xvlog + xelab + xsim --runall
     │
     └─2─► xsim work.testbench -gui -tclbatch wave.tcl
               │
               ├── wave.tcl carrega sinais no viewer:
               │     log_wave -recursive *
               │     add_wave /testbench/bfm_uart0/clk
               │     add_wave /testbench/bfm_reg0/irq
               │     ...
               │     run all
               │
               └── Janela Vivado abre no Windows (via WSLg)
                   com formas de onda do teste
```

---

## Pré-requisito para modo GUI: WSLg (Windows 11)

```
Windows 11
│
├── WSLg (incluso por padrão)
│     ├── Servidor X11 virtual em /tmp/.X11-unix/X0
│     └── Socket Wayland em /mnt/wslg/
│
└── WSL2 (Ubuntu-24.04)
      │
      ├── DISPLAY=:0  (automático no WSL2 com WSLg)
      │
      └── Docker Container
            ├── /tmp/.X11-unix montado ◄── volume do compose
            ├── /mnt/wslg montado      ◄── volume do compose
            ├── DISPLAY=:0             ◄── environment do compose
            │
            └── xsim -gui
                  └── desenha janela no display :0
                        └── aparece no Windows via WSLg ✓
```

**Verificar se WSLg está funcionando** (rodar no WSL2 antes de `make sim-gui`):

```bash
echo $DISPLAY          # deve mostrar :0
xterm &                # deve abrir uma janela no Windows
```

---

## Ciclo de vida do container

```
make sim-gui UVM_TEST=uart_parity_error_test
     │
     ├─ Container 1 (headless):
     │     nasce → compila/elabora/simula → DESTRUÍDO (--rm)
     │     artefatos ficam em uvm_activity/work/sim/uart_parity_error_test/
     │
     └─ Container 2 (GUI):
           nasce → xsim -gui abre janela → usuário inspeciona sinais
           fecha janela → DESTRUÍDO (--rm)

Os arquivos de saída (.wdb, .log) persistem no host
porque /workspace é bind mount do repositório local.
```

---

## Build da imagem (uma única vez)

```
make build
  └── docker compose build
        └── Dockerfile
              ├── FROM almalinux:9          (~200 MB)
              ├── dnf install libX11, gcc,  (~500 MB dependências)
              │   python3, ncurses, ...
              └── useradd vivado

Resultado: imagem fpga-vivado:dev (~700 MB) cacheada localmente
```

Após o build, todos os `make sim*` usam a imagem cacheada.
