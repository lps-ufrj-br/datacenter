# Slurm Cluster Node Stress Test Suite

Este diretório contém um conjunto de scripts para realizar testes de estresse concorrentes de **CPU** e **GPU** em todas as máquinas de uma fila (partição) do Slurm. 

O script de controle (`submit_stress.py`) descobre automaticamente quais nós pertencem à fila informada e submete um job Slurm individual (`sbatch`) direcionado para cada nó específico.

---

## Estrutura dos Arquivos

1. **`submit_stress.py`**: O script mestre em Python que deve ser rodado a partir do nó principal/login. Ele expande os nós da fila e agenda os jobs via `sbatch`.
2. **`stress_job.sh`**: O template de job do Slurm. Ele é executado nos nós computacionais para lançar os estresses de CPU e GPU.
3. **`cpu_stress.py`**: Um script Python executado em background no nó de destino que estressa todos os núcleos de CPU (100% de uso) realizando operações matemáticas em loop paralelo.
4. **`gpu_stress.cu`**: Código CUDA C++ que é compilado localmente no nó em `/tmp/gpu_stress` (para evitar concorrência/lock no NFS) e executa loops de kernels de cálculo matemático pesado em todas as GPUs detectadas.

---

## Como Usar

### 1. Executando o teste de estresse

Acesse o terminal no nó de login do cluster e execute o `submit_stress.py` passando a partição desejada e o tempo do teste em segundos.

**Estrutura do comando:**
```bash
python3 scripts/submit_stress.py <nome_da_fila> [duracao_em_segundos] [--cpu-only]
```

**Exemplos:**
* Estressar todas as máquinas da fila **gpu** por **300 segundos** (5 minutos):
  ```bash
  python3 scripts/submit_stress.py gpu 300
  ```
* Estressar a fila **cpu** por **60 segundos** (1 minuto):
  ```bash
  python3 scripts/submit_stress.py cpu 60
  ```
* Estressar **apenas a CPU** (ignorando as GPUs) de todas as máquinas da fila **gpu** por **120 segundos**:
  ```bash
  python3 scripts/submit_stress.py gpu 120 --cpu-only
  ```

*Se a duração não for fornecida, o tempo padrão será de **300 segundos**.*

### 2. Monitoramento

Você pode acompanhar o estado de execução dos jobs usando o comando padrão do Slurm:
```bash
squeue
```

### 3. Visualizando os resultados

Após o término da execução, os logs de saída serão gerados no diretório de execução no formato:
* `stress_test_<nome_do_no>_<job_id>.out` (Saída padrão contendo o progresso e detecções)
* `stress_test_<nome_do_no>_<job_id>.err` (Erros, se houver)

Exemplo de log bem-sucedido em nó com GPU:
```text
=========================================
Starting Stress Test on Host: caloba62
Date: Tue 25 Aug 2026 12:33:22 PM -03
Requested duration: 20 seconds
=========================================
Launching CPU stress...
Stressing 4 CPUs for 20 seconds...
Detected 1 GPU(s).
Compiling GPU stress code with /usr/local/cuda/bin/nvcc to /tmp/gpu_stress...
Launching GPU stress...
Starting GPU stress on 1 device(s) for 20 seconds...
Stopping CPU stress processes...
CPU stress finished.
GPU stress finished.
=========================================
Stress Test Finished on Host: caloba62
Date: Tue 25 Aug 2026 12:33:57 PM -03
=========================================
```
