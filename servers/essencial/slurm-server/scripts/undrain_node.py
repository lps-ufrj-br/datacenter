#!/usr/bin/env python3
import argparse
import subprocess
import sys

def run_command(command):
    """Run a system command and return the output."""
    try:
        print(f"Executing: {' '.join(command)}")
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        if result.stdout:
            print(result.stdout)
        if result.stderr:
            print(result.stderr, file=sys.stderr)
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}", file=sys.stderr)
        if e.stdout:
            print(f"Stdout: {e.stdout}", file=sys.stderr)
        if e.stderr:
            print(f"Stderr: {e.stderr}", file=sys.stderr)
        return False

def undrain_nodes(nodes):
    """Update node state to RESUME."""
    cmd = [
        "sudo", "scontrol", "update", f"nodename={nodes}", "state=RESUME"
    ]
    
    if run_command(cmd):
        print(f"Nodes '{nodes}' have been requested to resume.")
    else:
        print(f"Failed to undrain nodes '{nodes}'.")

def main():
    parser = argparse.ArgumentParser(description="Undrain (resume) Slurm nodes")
    parser.add_argument("nodes", help="Names of the nodes to undrain (e.g., node01 or node[01-05])")
    
    args = parser.parse_args()
    
    if args.nodes:
        undrain_nodes(args.nodes)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
