# Documento de Ambiente de Simulação

**Disciplina:** SD242 — Sistemas Digitais  
**Data:** 2026-04-21

---

## 1. Contexto e Motivação

Durante as aulas de laboratório, os testes de verificação UVM foram executados em um **cluster de máquinas virtuais** disponibilizado pela instituição. Essas VMs rodam **AlmaLinux** com Vivado 2025.2 instalado e configurado, e os scripts de compilação (`xvlog`, `xelab`, `xsim`) são invocados diretamente do terminal do cluster.

O objetivo deste documento é explicar como o mesmo ambiente foi reproduzido localmente, as decisões tomadas durante esse processo, e como qualquer pessoa pode replicar a configuração.

---

## 2. Por que usar Docker?

### 2.1 Replicar o ambiente do cluster fielmente

A principal razão para usar Docker foi **garantir que o ambiente de simulação local fosse idêntico ao do cluster**. Diferenças de sistema operacional, versão de bibliotecas ou configurações do Vivado podem gerar comportamentos distintos entre máquinas — inclusive falhas de compilação que não ocorrem no cluster (ou vice-versa).

Ao construir uma imagem Docker baseada em **AlmaLinux** (a mesma distribuição das VMs do laboratório), com os mesmos pacotes e a mesma versão do Vivado instalada, garante-se que:

- Os binários `xvlog`, `xelab` e `xsim` são exatamente os mesmos
- As variáveis de ambiente (`settings64.sh`) são configuradas da mesma forma
- O comportamento do simulador é idêntico ao observado em aula

### 2.2 Controle total sobre os arquivos

Outra vantagem importante: **todos os arquivos do Vivado e dos projetos ficam na máquina local**, não em servidores externos. Isso significa:

- Saber exatamente onde cada arquivo está (`/home/rafael/fpga/` no WSL)
- Poder versionar os scripts de simulação junto com o código RTL e UVM
- Não depender de conexão com o cluster para continuar o trabalho
- Scripts idênticos aos do cluster podem ser executados localmente sem adaptação

### 2.3 Por que não simplesmente criar um container com Vivado dentro?

O Vivado **exige uma conta Xilinx/AMD e uma licença ativa** para instalação e uso. Não é possível distribuir o Vivado dentro de uma imagem Docker pública nem automatizar completamente sua instalação sem credenciais válidas.

Por isso, a abordagem adotada foi diferente: **replicar o volume do AlmaLinux** (a instalação completa do Vivado e pacotes extras que existe nas VMs do cluster) e **montá-lo como volume Docker** na máquina local. O container em si é apenas um executor — o Vivado real está no disco local, exatamente como está no cluster.

---

## 3. Arquitetura do Ambiente

```
Máquina local (Windows 11 + WSL Ubuntu-24.04)
│
├── /home/rafael/fpga/                    ← repositório do projeto (montado em /workspace)
│   ├── uvm_activity/                     ← código RTL + testbench UVM
│   ├── scripts/                          ← scripts de compilação/simulação
│   ├── docker-compose.vivado.yml         ← configuração do serviço Docker
│   └── docs/                             ← documentação
│
└── /home/rafael/2025.2/                  ← Vivado 2025.2 instalado (montado em /workspace/2025.2)
    ├── Vivado/settings64.sh              ← script de configuração de ambiente
    └── Vivado/bin/xvlog, xelab, xsim    ← binários do simulador

Docker (imagem: fpga-vivado:dev)
│   Base: AlmaLinux (idêntica às VMs do cluster)
│   Pacotes extras instalados: gcc, make, perl, python3, libX11, ...
│
└── Container efêmero (--rm) ao rodar cada simulação
    ├── /workspace       ← montado do host: /home/rafael/fpga/
    └── /workspace/2025.2 ← montado do host: /home/rafael/2025.2/
```

O container é **efêmero**: nasce para rodar a simulação e é destruído ao terminar. Todo o estado persiste nos volumes montados do host.

---

## 4. Estrutura do `docker-compose.vivado.yml`

```yaml
services:
  vivado:
    image: fpga-vivado:dev
    volumes:
      - /home/rafael/fpga:/workspace          # código do projeto
      - /home/rafael/2025.2:/workspace/2025.2 # instalação local do Vivado
    working_dir: /workspace
```

O comando padrão para rodar um teste:

```bash
docker compose -f docker-compose.vivado.yml run --rm vivado \
  bash -c 'source /workspace/2025.2/Vivado/settings64.sh && \
           UVM_TEST=uart_baud_rate_test bash /workspace/uvm_activity/scripts/sim_uvm_xsim.sh'
```

O `source settings64.sh` é o mesmo passo realizado no cluster antes de qualquer compilação — ele adiciona os binários do Vivado ao `PATH` e configura variáveis de ambiente necessárias.

---

## 5. Como Reproduzir o Ambiente

### 5.1 Pré-requisitos

| Requisito | Notas |
|-----------|-------|
| Windows 10/11 com WSL2 | Ou Linux nativo — os caminhos mudam |
| Docker Desktop | Com integração WSL2 habilitada |
| Conta Xilinx/AMD | Necessária para download e licença do Vivado |
| Vivado 2025.2 (Linux) | Instalado localmente (~50 GB) |
| Git | Para clonar o repositório |

### 5.2 Passo 1 — Instalar o Vivado localmente

1. Acesse [xilinx.com](https://www.xilinx.com) e faça login com sua conta AMD/Xilinx
2. Baixe o **Vivado ML Edition 2025.2** (instalador Linux)
3. No WSL, instale na pasta desejada:

```bash
chmod +x Vivado_2025.2_*_Lin64.bin
./Vivado_2025.2_*_Lin64.bin
# Selecione destino: /home/<user>/2025.2
# Componentes mínimos: Vivado + xsim (simulador)
```

> **Importante:** a licença do Vivado está vinculada à conta. Sem login e ativação, o xsim não executa. Este passo não pode ser automatizado nem distribuído.

### 5.3 Passo 2 — Construir a imagem Docker

```bash
cd /home/rafael/fpga
docker compose -f docker-compose.vivado.yml build
```

O `Dockerfile` (na raiz do projeto) define:
- Base: `almalinux:9` (idêntica às VMs do cluster)
- Instalação de dependências do Vivado: `gcc`, `make`, `perl`, `libX11`, `libXrender`, `libXtst`, `glibc-devel`, `ncurses-libs`, etc.

### 5.4 Passo 3 — Clonar o repositório

```bash
git clone <url-do-repositório> /home/rafael/fpga
cd /home/rafael/fpga
```

### 5.5 Passo 4 — Executar os testes

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

### 5.6 Usuários Windows (Git Bash / PowerShell)

Se rodar Docker a partir do Git Bash no Windows (não do WSL), os caminhos precisam de ajuste para evitar conversão automática de paths:

```bash
# Git Bash — usar // no início para evitar conversão de path
cd //wsl.localhost/Ubuntu-24.04/home/rafael/fpga
docker compose -f docker-compose.vivado.yml run --rm vivado \
  bash -c 'source /workspace/2025.2/Vivado/settings64.sh && \
           UVM_TEST=uart_baud_rate_test bash /workspace/uvm_activity/scripts/sim_uvm_xsim.sh'
```

---

## 6. Por que não usar a VM do cluster diretamente?

| Aspecto | Cluster (VM do laboratório) | Ambiente local (Docker + volume) |
|---------|---------------------------|----------------------------------|
| Disponibilidade | Apenas durante aulas / VPN | 24/7, sem dependência de rede |
| Controle dos arquivos | Arquivos no servidor | Tudo em disco local, versionável |
| Reprodutibilidade | Depende do estado da VM | Container idêntico toda execução |
| Ambiente | AlmaLinux + Vivado 2025.2 | **Idêntico** (mesma base, mesmo Vivado) |
| Licença Vivado | Gerenciada pelo laboratório | **Conta pessoal obrigatória** |
| Colaboração | Difícil (acesso restrito) | Qualquer pessoa com conta Xilinx reproduz |

A abordagem local **não elimina** o requisito de conta Xilinx — ela apenas move o Vivado para o disco local e envolve o ambiente em Docker para garantir paridade com o cluster.

---

## 7. Relação com o Fluxo de Simulação no Cluster

O script `uvm_activity/scripts/sim_uvm_xsim.sh` foi escrito para ser **idêntico ao que seria executado no cluster**. Os comandos internos são:

```bash
# 1. Compilar RTL + sim (equivalente ao que o cluster executa)
xvlog -sv -L uvm \
  uvm_activity/rtl/*.sv \
  uvm_activity/sim/*.sv \
  --work work

# 2. Elaborar
xelab testbench -L uvm -L work \
  --timescale 1ns/100ps \
  --snapshot testbench_snap

# 3. Simular
xsim testbench_snap \
  --testplusarg "UVM_TESTNAME=${UVM_TEST}" \
  --testplusarg "UVM_VERBOSITY=UVM_LOW" \
  --runall
```

A única diferença do cluster é que aqui `xvlog`, `xelab` e `xsim` são encontrados via `settings64.sh` a partir do volume montado, enquanto no cluster eles estão no `PATH` por padrão após o login.
