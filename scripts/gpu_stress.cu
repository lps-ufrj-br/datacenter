#include <iostream>
#include <chrono>
#include <thread>
#include <vector>
#include <cuda_runtime.h>
#include <cmath>

__global__ void stress_kernel(float* d_data, int size, int iterations) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < size) {
        float val = d_data[idx];
        for (int i = 0; i < iterations; ++i) {
            val = val * 1.000001f + 0.0001f;
            val = sinf(val) * cosf(val);
        }
        d_data[idx] = val;
    }
}

void stress_device(int device_id, int duration_sec) {
    cudaError_t err = cudaSetDevice(device_id);
    if (err != cudaSuccess) {
        std::cerr << "Failed to set device " << device_id << ": " << cudaGetErrorString(err) << std::endl;
        return;
    }
    
    // Allocate ~64MB of GPU memory to test memory access as well
    int size = 1 << 24; 
    size_t bytes = size * sizeof(float);
    float* h_data = (float*)malloc(bytes);
    if (!h_data) {
        std::cerr << "Failed to allocate host memory" << std::endl;
        return;
    }
    for (int i = 0; i < size; ++i) h_data[i] = (float)i;
    
    float* d_data = nullptr;
    err = cudaMalloc(&d_data, bytes);
    if (err != cudaSuccess) {
        std::cerr << "Failed to allocate device memory on GPU " << device_id << ": " << cudaGetErrorString(err) << std::endl;
        free(h_data);
        return;
    }
    
    err = cudaMemcpy(d_data, h_data, bytes, cudaMemcpyHostToDevice);
    if (err != cudaSuccess) {
        std::cerr << "Failed to copy to device memory on GPU " << device_id << ": " << cudaGetErrorString(err) << std::endl;
        cudaFree(d_data);
        free(h_data);
        return;
    }
    
    int threads_per_block = 256;
    int blocks = (size + threads_per_block - 1) / threads_per_block;
    
    auto start_time = std::chrono::steady_clock::now();
    
    while (true) {
        auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::steady_clock::now() - start_time
        ).count();
        if (elapsed >= duration_sec) {
            break;
        }
        
        // Launch a kernel with a high iteration count to keep the GPU busy
        stress_kernel<<<blocks, threads_per_block>>>(d_data, size, 50000);
        
        err = cudaDeviceSynchronize();
        if (err != cudaSuccess) {
            std::cerr << "CUDA kernel execution failed on GPU " << device_id << ": " << cudaGetErrorString(err) << std::endl;
            break;
        }
    }
    
    cudaFree(d_data);
    free(h_data);
}

int main(int argc, char** argv) {
    int duration_sec = 60;
    if (argc > 1) {
        duration_sec = atoi(argv[1]);
    }
    
    int device_count = 0;
    cudaError_t err = cudaGetDeviceCount(&device_count);
    if (err != cudaSuccess) {
        std::cerr << "CUDA Error when querying device count: " << cudaGetErrorString(err) << std::endl;
        return 1;
    }
    
    if (device_count == 0) {
        std::cerr << "No GPU devices found." << std::endl;
        return 1;
    }
    
    std::cout << "Starting GPU stress on " << device_count << " device(s) for " << duration_sec << " seconds..." << std::endl;
    
    std::vector<std::thread> threads;
    for (int i = 0; i < device_count; ++i) {
        threads.emplace_back(stress_device, i, duration_sec);
    }
    
    for (auto& t : threads) {
        t.join();
    }
    
    std::cout << "GPU stress finished." << std::endl;
    return 0;
}
