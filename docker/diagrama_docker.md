# Diagrama — Como o Docker Compose funciona neste projeto

## Visão geral do fluxo

```
  Usuário
     │
     │  make sim-baud
     ▼
┌─────────────────────────────────────────────────────┐
│  Makefile  (relatorio_sd242/Makefile)               │
│                                                     │
│  COMPOSE_FILE = docker/docker-compose.yml           │
│  SIM_SCRIPT  = /workspace/uvm_activity/scripts/...  │
│                                                     │
│  docker compose -f docker/docker-compose.yml        │
│    run --rm vivado bash -c                          │
│    "source settings64.sh && UVM_TEST=... bash ..."  │
└─────────────────┬───────────────────────────────────┘
                  │ invoca
                  ▼
┌─────────────────────────────────────────────────────┐
│  docker-compose.yml  (relatorio_sd242/docker/)      │
│                                                     │
│  build:                                             │
│    context: .  ◄── mesma pasta docker/              │
│    dockerfile: Dockerfile                           │
│                                                     │
│  volumes:                                           │
│    ../../  →  /workspace          (projeto)         │
│    ../../2025.2  →  /workspace/2025.2  (Vivado)     │
└──────┬──────────────────┬───────────────────────────┘
       │ build            │ monta volumes
       ▼                  ▼
┌─────────────┐   ┌────────────────────────────────────┐
│ Dockerfile  │   │  Container efêmero (--rm)          │
│             │   │                                    │
│ FROM        │   │  /workspace/                       │
│ almalinux:9 │   │  ├── uvm_activity/                 │
│             │   │  │   ├── rtl/                      │
│ instala:    │   │  │   ├── sim/                      │
│ gcc, make,  │   │  │   └── scripts/sim_uvm_xsim.sh  │
│ libX11,     │   │  │                                 │
│ python3,    │   │  └── 2025.2/Vivado/               │
│ ncurses,    │   │      ├── settings64.sh  ◄─ source  │
│ openssl...  │   │      └── bin/                      │
│             │   │          ├── xvlog  ◄─ compila     │
│ USER vivado │   │          ├── xelab  ◄─ elabora     │
└─────────────┘   │          └── xsim   ◄─ simula      │
                  └────────────────────────────────────┘


```

---

## Mapeamento de pastas: host → container

```
HOST (WSL /home/rafael/fpga/)          CONTAINER (/workspace/)
─────────────────────────────────      ──────────────────────────────────
relatorio_sd242/           ──────────► /workspace/relatorio_sd242/
uvm_activity/              ──────────► /workspace/uvm_activity/
│  ├── rtl/*.sv            ──────────► /workspace/uvm_activity/rtl/*.sv
│  ├── sim/*.sv            ──────────► /workspace/uvm_activity/sim/*.sv
│  └── scripts/            ──────────► /workspace/uvm_activity/scripts/
2025.2/Vivado/             ──────────► /workspace/2025.2/Vivado/
│  ├── settings64.sh                    (configura PATH dos binários)
│  └── bin/xvlog,xelab,xsim            (ferramentas de simulação)
```

> O container não tem os binários do Vivado embutidos — eles ficam no host
> e são acessados via volume. O Dockerfile instala apenas as **dependências
> de sistema** (bibliotecas, compiladores) que o Vivado precisa para rodar.

---

## Sequência de execução dentro do container

```
bash -c "source /workspace/2025.2/Vivado/settings64.sh
         && UVM_TEST=uart_baud_rate_test
            bash /workspace/uvm_activity/scripts/sim_uvm_xsim.sh"
         │
         ├─► source settings64.sh
         │     └── adiciona xvlog/xelab/xsim ao PATH
         │
         └─► sim_uvm_xsim.sh
               │
               ├─1─► xvlog -sv -L uvm  rtl/*.sv sim/*.sv
               │       └── compila SystemVerilog → work/
               │
               ├─2─► xelab testbench -L uvm -L work
               │       └── elabora hierarquia → snapshot
               │
               └─3─► xsim snapshot --testplusarg UVM_TESTNAME=...
                       └── simula → simulate.log
                             └── grep PASS/FAIL → veredicto
```

---

## Ciclo de vida do container

```
make sim-baud
     │
     ├──► docker compose run --rm vivado bash -c "..."
     │         │
     │         ├── container NASCE   (imagem fpga-vivado:dev)
     │         ├── volumes MONTADOS  (host → /workspace)
     │         ├── comando EXECUTADO (source + sim_script)
     │         └── container DESTRUÍDO (--rm)
     │
     └──► logs e artefatos ficam em uvm_activity/work/sim/<teste>/
          (persistem no host porque /workspace é um bind mount)
```

---

## Como fazer build da imagem (uma única vez)

```
make build
  └── docker compose -f docker/docker-compose.yml build
        └── Dockerfile
              ├── FROM almalinux:9        (~200 MB base)
              ├── dnf install ...         (~500 MB dependências)
              └── useradd vivado          (usuário sem root)

Resultado: imagem fpga-vivado:dev (~700 MB) salva localmente no Docker
```

Após o build, `make sim`, `make sim-all` etc. usam a imagem cacheada sem
precisar reconstruir.
