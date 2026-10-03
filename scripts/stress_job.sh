#!/bin/bash
#SBATCH --job-name=cluster_stress_test
#SBATCH --output=stress_test_%N_%j.out
#SBATCH --error=stress_test_%N_%j.err
#SBATCH --time=02:00:00

# Duration in seconds (passed via sbatch --export or default to 300 seconds)
DURATION=${DURATION:-300}

echo "========================================="
echo "Starting Stress Test on Host: $(hostname)"
echo "Date: $(date)"
echo "Requested duration: $DURATION seconds"
echo "========================================="

# 1. Run CPU stress in the background
echo "Launching CPU stress..."
python3 /home/cluster/datacenter/scripts/cpu_stress.py $DURATION &
CPU_PID=$!

# 2. Check for GPU presence
ONLY_CPU=${ONLY_CPU:-0}
HAS_GPU=0
if [ "$ONLY_CPU" -ne 1 ]; then
    if command -v nvidia-smi &> /dev/null; then
        NUM_GPUS=$(nvidia-smi --query-gpu=name --format=csv,noheader | wc -l)
        if [ "$NUM_GPUS" -gt 0 ]; then
            HAS_GPU=1
        fi
    fi
else
    echo "GPU stress bypassed (CPU-only mode requested)."
fi

GPU_PID=""
if [ "$HAS_GPU" -eq 1 ]; then

    echo "Detected $NUM_GPUS GPU(s)."
    
    # Check if compiled binary exists in /tmp
    if [ ! -f /tmp/gpu_stress ]; then
        # Find nvcc compiler
        NVCC_PATH=$(which nvcc 2>/dev/null)
        if [ -z "$NVCC_PATH" ]; then
            if [ -f /usr/local/cuda/bin/nvcc ]; then
                NVCC_PATH="/usr/local/cuda/bin/nvcc"
            elif [ -f /usr/local/cuda-12.1/bin/nvcc ]; then
                NVCC_PATH="/usr/local/cuda-12.1/bin/nvcc"
            fi
        fi
        
        if [ -n "$NVCC_PATH" ]; then
            echo "Compiling GPU stress code with $NVCC_PATH to /tmp/gpu_stress..."
            $NVCC_PATH -O3 -o /tmp/gpu_stress /home/cluster/datacenter/scripts/gpu_stress.cu -lpthread
        else
            echo "Warning: nvcc compiler not found. Cannot compile GPU stress code."
        fi
    fi
    
    if [ -f /tmp/gpu_stress ]; then
        echo "Launching GPU stress..."
        /tmp/gpu_stress $DURATION &
        GPU_PID=$!
    else
        echo "Warning: /tmp/gpu_stress binary not available. Skipping GPU stress."
    fi
else
    if [ "$ONLY_CPU" -ne 1 ]; then
        echo "No GPUs detected on this node."
    fi
fi

# 3. Wait for both tests to finish
wait $CPU_PID
if [ -n "$GPU_PID" ]; then
    wait $GPU_PID
fi

echo "========================================="
echo "Stress Test Finished on Host: $(hostname)"
echo "Date: $(date)"
echo "========================================="
