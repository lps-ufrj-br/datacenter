#!/usr/bin/env python3
import sys
import os
import subprocess
import argparse

def main():
    parser = argparse.ArgumentParser(description="Submete testes de estresse de CPU e GPU no Slurm por nó.")
    parser.add_argument("partition", help="Nome da partição/fila do Slurm")
    parser.add_argument("duration", type=int, nargs="?", default=300, help="Duração do teste em segundos (padrão: 300)")
    parser.add_argument("--cpu-only", action="store_true", help="Executa apenas teste de estresse de CPU, ignorando as GPUs")
    
    args = parser.parse_args()
    
    partition = args.partition
    duration = args.duration
    only_cpu = 1 if args.cpu_only else 0
    
    # Get nodelist for partition
    try:
        nodelist = subprocess.check_output(
            ["sinfo", "-h", "-p", partition, "-o", "%N"], 
            text=True
        ).strip()
    except subprocess.CalledProcessError:
        print(f"Error: Failed to query partition '{partition}'. Does it exist?")
        sys.exit(1)
        
    if not nodelist or nodelist == "n/a" or nodelist == "":
        print(f"Error: No nodes found in partition '{partition}'.")
        sys.exit(1)
        
    # Expand nodelist using scontrol show hostnames
    try:
        nodes = subprocess.check_output(
            ["scontrol", "show", "hostnames", nodelist],
            text=True
        ).strip().splitlines()
    except subprocess.CalledProcessError:
        print(f"Error: Failed to expand nodelist '{nodelist}'.")
        sys.exit(1)
        
    if not nodes:
        print(f"Error: No nodes parsed from nodelist '{nodelist}'.")
        sys.exit(1)
        
    print(f"Submitting stress test to {len(nodes)} node(s) in partition '{partition}'...")
    print(f"Target nodes: {', '.join(nodes)}")
    print(f"Duration: {duration} seconds")
    if only_cpu:
        print("Mode: CPU Only")
    else:
        print("Mode: CPU and GPU (if available)")
    print("-" * 50)
    
    script_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stress_job.sh")
    
    success_count = 0
    for node in nodes:
        # Submit job using sbatch
        cmd = [
            "sbatch",
            f"--partition={partition}",
            f"--nodelist={node}",
            "--exclusive",
            f"--export=ALL,DURATION={duration},ONLY_CPU={only_cpu}",
            script_path
        ]
        
        try:
            output = subprocess.check_output(cmd, text=True).strip()
            print(f"Node {node}: {output}")
            success_count += 1
        except subprocess.CalledProcessError as e:
            err_msg = e.output.strip() if e.output else str(e)
            print(f"Node {node}: Failed to submit job. Error: {err_msg}")
            
    print("-" * 50)
    print(f"Successfully submitted {success_count}/{len(nodes)} job(s).")
    print("You can monitor the jobs using 'squeue'.")

if __name__ == "__main__":
    main()

