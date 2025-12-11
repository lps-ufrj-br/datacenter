# A Guide to Using Singularity on an HPC Cluster

This guide will walk you through the essential steps of using Singularity on a High-Performance Computing (HPC) cluster. We'll cover how to pull an image from Docker Hub and how to execute and run a Singularity image.

## Prerequisites

  * **Access to an HPC cluster:** You must have an account on an HPC cluster with Slurm and Singularity installed.
  * **A Docker Hub account:** You will need an account to be able to pull images.
  * **Basic familiarity with the command line:** This guide assumes you have a basic understanding of how to navigate a Linux environment.

-----

## 1\. Pulling an Image from Docker Hub

Singularity can directly pull images from Docker Hub. This is the most common way to get an image onto the cluster. The `singularity pull` command will convert the Docker image into a Singularity Image Format (SIF) file. This SIF file is a single, executable file that contains the entire container.

The general syntax is:

```bash
singularity pull <image_name>.sif docker://<docker_hub_username>/<docker_image_name>:<tag>
```

  * `<image_name>.sif`: This is the name you want to give your local Singularity image file. It's a good practice to use the `.sif` extension.
  * `docker://`: This is the URI for Docker Hub.
  * `<docker_hub_username>`: Your Docker Hub username. For official images, this is omitted.
  * `<docker_image_name>`: The name of the Docker image.
  * `<tag>`: The specific version of the image (e.g., `latest`, `1.2.3`). If not specified, `latest` is used.

### Example: Pulling a Python Image

Let's pull the official `python:3.9` image from Docker Hub.

1.  **Log in to your HPC cluster.**

2.  **Navigate to your working directory.** It's recommended to pull images into a location with sufficient storage, such as your home directory or a project directory.

3.  **Run the `singularity pull` command.**

    ```bash
    singularity pull python3.9.sif docker://python:3.9
    ```

    You will see output similar to this as Singularity downloads and converts the image:

    ```
    INFO:    Starting container image pull...
    INFO:    Converting OCI blobs to SIF format
    INFO:    Pull complete: python3.9.sif
    ```

    You now have a file named `python3.9.sif` in your current directory.

-----

## 2\. Executing and Running a Singularity Image

Once you have a Singularity image (a `.sif` file), you can interact with it in several ways. The most common commands are `singularity exec` and `singularity run`.

### `singularity exec`

The `exec` command allows you to execute a specific command inside the container. This is useful for running a single command or for inspecting the container's environment.

The general syntax is:

```bash
singularity exec <path_to_image>.sif <command_to_execute>
```

#### Example: Checking Python version

Let's use the `exec` command to check the Python version inside the image we just pulled.

```bash
singularity exec python3.9.sif python --version
```

The output will be:

```
Python 3.9.18
```

This confirms that you are running the `python` command from inside the container, not from your host system.

#### Example: Running a script

If you have a Python script named `my_script.py` in your current directory, you can run it with `singularity exec`. Singularity automatically mounts your home and working directories into the container, so you can access your files.

```bash
singularity exec python3.9.sif python my_script.py
```

### `singularity run`

The `run` command executes the default run script defined within the container's metadata. This is a convenient way to run the main application of the container without needing to specify the full command.

The general syntax is simply:

```bash
singularity run <path_to_image>.sif
```

#### Example: Running the default command

The official Python Docker image has a default run command that starts an interactive Python interpreter.

```bash
singularity run python3.9.sif
```

This will launch an interactive Python session inside the container:

```
Python 3.9.18 (main, Oct 25 2023, 21:04:15)
[GCC 12.2.0] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>>
```

You can now use this interactive interpreter. To exit, type `exit()` and press Enter.

### Using Slurm with Singularity

For production jobs, you will typically use Slurm to submit a batch job. The Slurm script will contain the `singularity exec` or `singularity run` commands.

Here is a basic example of a Slurm script (`my_job.sh`) to run a Python script inside your Singularity container.

```bash
#!/bin/bash
#SBATCH --job-name=python_job
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:10:00

# Load any required modules if necessary
# module load singularity

# Run your Python script inside the Singularity container
singularity exec /path/to/your/python3.9.sif python my_script.py
```

To submit this job, use the `sbatch` command:

```bash
sbatch my_job.sh
```

-----

**Congratulations\!** You now know the fundamental steps to pull, run, and execute commands within a Singularity container on an HPC cluster.

-----

# LPS page:

Back to the [main](https://sites.google.com/lps.ufrj.br/lps/início) page!
