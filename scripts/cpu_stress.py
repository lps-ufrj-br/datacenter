#!/usr/bin/env python3
import sys
import time
import multiprocessing
import os
import math
import signal

def cpu_burner():
    # Ignore SIGINT in child processes so they can be cleaned up by parent or term signals
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    while True:
        x = 0.0001
        for _ in range(10000):
            x = x * 1.000001 + 0.0001
            x = math.sin(x) * math.cos(x)

def main():
    if len(sys.argv) < 2:
        print("Usage: cpu_stress.py <duration_seconds>")
        sys.exit(1)
    
    try:
        duration = int(sys.argv[1])
    except ValueError:
        print("Error: Duration must be an integer (seconds)")
        sys.exit(1)
        
    try:
        num_cpus = len(os.sched_getaffinity(0))
    except AttributeError:
        num_cpus = os.cpu_count() or 1
        
    print(f"Stressing {num_cpus} CPUs for {duration} seconds...", flush=True)
    
    processes = []
    for _ in range(num_cpus):
        p = multiprocessing.Process(target=cpu_burner)
        p.daemon = True
        p.start()
        processes.append(p)
        
    try:
        time.sleep(duration)
    except KeyboardInterrupt:
        print("Stress test interrupted by user.", flush=True)
    finally:
        print("Stopping CPU stress processes...", flush=True)
        for p in processes:
            p.terminate()
            p.join()
        print("CPU stress finished.", flush=True)

if __name__ == "__main__":
    main()
