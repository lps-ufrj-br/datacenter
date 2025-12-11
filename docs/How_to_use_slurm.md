# Caloba Slurm Cluster Usage Tutorial 💻

This document serves as a comprehensive guide to utilizing the essential commands of the Slurm Workload Manager on the Caloba cluster. The commands covered include **`salloc`**, **`squeue`**, **`scancel`**, and **`sbatch`**.

-----

## 1\. Interactive Resource Allocation with `salloc` 🧠

The `salloc` command is used to allocate resources for a job and provide an interactive shell on the assigned compute node. This functionality is particularly useful for debugging, compiling software, and conducting interactive tests.

### Syntax

The general syntax is as follows:

```bash
salloc [options]
```

### Partitions (Queues) 📋

The Caloba cluster is configured with the following partitions:

| Partition  | Description                                                              |
|------------|--------------------------------------------------------------------------|
| `cpu-large`| Designated for CPU-intensive jobs with substantial memory requirements.  |
| `gpu`      | Allocated for jobs requiring a single GPU.                               |
| `gpu-large`| Dedicated to jobs that necessitate multiple GPUs.                        |

### Usage Examples 💡

**1. CPU Node Allocation:**
To allocate a single node from the `cpu-large` partition with 8 CPU cores, execute:

```bash
salloc --partition=cpu-large
```

**2. GPU Node Allocation:**
To request a single GPU from the `gpu` partition, use the `--gres` option:

```bash
salloc --partition=gpu
```

Upon allocation, one may verify GPU access by running **`nvidia-smi`**.

-----

## 2\. Job Status Monitoring with `squeue` 🚦

The `squeue` command allows users to monitor the status of jobs in the queue.

### Usage

To display a list of all jobs submitted by the current user, use the `--me` flag:

```bash
squeue --me
```

The output will provide information such as job ID, partition, job name, user, status (e.g., `R` for Running, `PD` for Pending), and resource utilization.

### Common Options

  * `squeue -u <username>`: Displays jobs for a specified user.
  * `squeue -t PD`: Filters the output to show only pending jobs.
  * `squeue -t R`: Filters the output to show only running jobs.
  * `squeue -j <job_id>`: Provides detailed information for a specific job ID.

-----

## 3\. Job Termination with `scancel` 

The `scancel` command is used to terminate a job that is either running or pending.

### Usage

To cancel a single job, the job ID must be provided:

```bash
scancel <job_id>
```

### Advanced Options

  * `scancel --user=<username>`: Cancels all jobs submitted by the specified user.
  * `scancel -u <username> --state=PD`: Cancels all pending jobs for the specified user.

-----

# LPS page:

Back to the [main](https://sites.google.com/lps.ufrj.br/lps/início) page!
