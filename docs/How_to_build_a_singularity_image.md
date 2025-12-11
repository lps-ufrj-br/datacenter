
# How to build a Singularity image?

This tutorial will guide you through the process of building a custom Singularity image using a definition file. This method is highly recommended for creating reproducible and shareable container environments. We will use an example to build an image for a PyTorch environment with GPU support, based on an Ubuntu Linux base.

## 1\. Understanding the Singularity Definition File

A Singularity Definition File (often with a `.def` extension) is a blueprint for building a container. It's a plain text file that specifies the base operating system, the software to install, environment variables, and other configurations.

The file is divided into two main parts:

  * **Header:** Defines the base image to build from.
  * **Sections:** Specifies the commands to run and data to include during the build process. Each section is marked by a `%` character.

### Key Sections

  * `%post`: This is the most crucial section. The commands here are executed inside the container environment with root privileges during the build process. This is where you install software, libraries, and dependencies.
  * `%environment`: Sets environment variables that will be available when the container is run.
  * `%runscript`: Defines the default command that is executed when you run the container with `singularity run`.
  * `%test`: A script that is executed after the build to verify the container's functionality.

## 2\. Creating the PyTorch Definition File

We will create a file named `pytorch_gpu.def` that builds a container with PyTorch and CUDA support. This example uses a pre-existing Docker image from the NVIDIA container registry as our base, which simplifies the process of getting the correct CUDA and cuDNN libraries.

Open a text editor and save the following content as `pytorch_gpu.def`.

```singularity
Bootstrap: docker
From: nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu22.04

%post
    # This section is executed as root inside the container during the build.

    # Update package lists and install basic dependencies
    apt-get update
    apt-get install -y --no-install-recommends \
        python3-pip \
        python3-dev \
        git

    # Install PyTorch and other common libraries
    # The --extra-index-url is crucial for installing PyTorch with CUDA support.
    pip3 install --no-cache-dir \
        torch \
        torchaudio \
        torchvision \
        numpy \
        matplotlib

    # Clean up APT and pip caches to reduce image size
    apt-get clean
    rm -rf /var/lib/apt/lists/*
    rm -rf /root/.cache/pip

%environment
    # Set environment variables for the container runtime.
    # This ensures Python and other binaries are in the PATH.
    export PATH=/usr/bin:$PATH
    
%runscript
    # The default command to run when the image is executed with `singularity run`.
    # This will launch a Python interactive session.
    exec python3 "$@"

%test
    # This script is run after the build to verify it was successful.
    echo "Running container tests..."
    
    # Check if PyTorch is installed and can see the GPU
    python3 -c "import torch; print(f'PyTorch version: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); assert torch.cuda.is_available()"
    
    echo "Tests passed successfully."
```

### Explanation of the Definition File

  * **`Bootstrap: docker`**: This tells Singularity to use a Docker image as the base for the build.
  * **`From: nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu22.04`**: We are starting with an official NVIDIA container that already includes the CUDA toolkit and cuDNN libraries. This saves a lot of effort and potential compatibility issues.
  * **`%post`**: This section installs `python3-pip`, `python3-dev`, and `git` using `apt`. It then uses `pip3` to install PyTorch and other libraries. The `torch` package is configured to use the existing CUDA libraries from the base image. Finally, it cleans up unnecessary files to keep the image small.
  * **`%environment`**: This section ensures that `/usr/bin` is in the PATH, so commands like `python3` can be found.
  * **`%runscript`**: If you simply run `singularity run pytorch_gpu.sif`, this script will execute, starting an interactive Python session.
  * **`%test`**: This is a great way to verify your build. The script uses Python to check if PyTorch is installed, if it can detect a GPU, and if the GPU is available.

## 3\. Building the Singularity Image

Building a Singularity image from a definition file often requires elevated privileges because it modifies the file system. On an HPC cluster, you are typically a non-root user. The `fakeroot` flag is designed for this scenario, allowing a user to build an image without needing actual root access.

### The Build Command

The general syntax is:

```bash
singularity build --fakeroot <output_image_name>.sif <definition_file_name>.def
```

1.  **Log in to your HPC cluster.**

2.  **Navigate to the directory** where you saved your `pytorch_gpu.def` file.

3.  **Run the build command:**

    ```bash
    singularity build --fakeroot pytorch_gpu.sif pytorch_gpu.def
    ```

    The build process will take some time, as Singularity pulls the base image, runs the `%post` script to install packages, and then compresses everything into a single `.sif` file. You will see detailed output as each step is completed.

      * **Note:** If your cluster's Singularity version is older and does not support `--fakeroot`, you will need to ask an administrator to build the image for you or use a build service.

## 4\. Using the Built Image

Once the build is complete, you will have a single file named `pytorch_gpu.sif`. This file is your complete, self-contained container.

### Running a Command with GPU Support

To run a command inside your container and utilize the GPU, you must use the `--nv` flag with `singularity exec`. This flag is crucial as it binds the necessary NVIDIA drivers from the host system into the container.

```bash
singularity exec --nv pytorch_gpu.sif python3 my_script.py
```

### Starting an Interactive Session

For an interactive session (e.g., debugging or using a Jupyter Notebook), use `singularity shell`. The `--nv` flag is still required for GPU access.

```bash
singularity shell --nv pytorch_gpu.sif
```

You are now inside the container. You can verify GPU access with a simple Python script:

```python
import torch

print("Is CUDA available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("Number of GPUs:", torch.cuda.device_count())
    print("GPU Name:", torch.cuda.get_device_name(0))
```

This will confirm that your container is ready for GPU-accelerated PyTorch workloads.

-----

# LPS page:

Back to the [main](https://sites.google.com/lps.ufrj.br/lps/início) page!
