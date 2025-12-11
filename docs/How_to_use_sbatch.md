
# Batch Job Submission with `sbatch` 📝

For non-interactive, long-running tasks, `sbatch` is used to submit a job script to the queue. The job will commence execution when the requested resources become available.

## Job Script Structure

A batch script is a shell script that begins with **`#SBATCH`** directives, which specify the job's resource requirements.

### Example: Machine Learning Training with Output JSON 🤖

A common practice in machine learning is to output the final model metrics and parameters to a file for later analysis. This example demonstrates a job that accepts parameters and outputs a JSON file with a user-defined name.

First, let's update our Python script, `train_model.py`, to accept an output file name and write results to it.

```python
import argparse
import os
import torch
import json

def train_model(epochs, learning_rate, batch_size, output_file):
    """
    A placeholder function for a machine learning training process.
    """
    print(f"Starting training with the following parameters:")
    print(f"Epochs: {epochs}")
    print(f"Learning Rate: {learning_rate}")
    print(f"Batch Size: {batch_size}")
    
    # Check for GPU availability
    if torch.cuda.is_available():
        print("GPU is available. Using it for training.")
        device = torch.device("cuda")
    else:
        print("GPU not available. Falling back to CPU.")
        device = torch.device("cpu")
        
    print(f"Training on device: {device}")
    
    # Placeholder for your actual training code
    # ...
    
    # Simulate a result
    final_metrics = {
        "epochs": epochs,
        "learning_rate": learning_rate,
        "batch_size": batch_size,
        "final_accuracy": 0.95 + (epochs * 0.001)  # Simulated result
    }
    
    # Write the results to the specified output file
    with open(output_file, 'w') as f:
        json.dump(final_metrics, f, indent=4)
    
    print(f"Training complete! Metrics saved to {output_file}. 🎉")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Machine Learning Training Script")
    parser.add_argument("--epochs", type=int, default=10, help="Number of training epochs")
    parser.add_argument("--learning-rate", type=float, default=0.001, help="Optimizer learning rate")
    parser.add_argument("--batch-size", type=int, default=32, help="Batch size for training")
    parser.add_argument("--output-file", type=str, required=True, help="Path to the output JSON file")
    
    args = parser.parse_args()
    
    train_model(args.epochs, args.learning_rate, args.batch_size, args.output_file)

```

Now, here is the `sbatch` script to run this job, passing the parameters and a dynamically named output file.

```bash
#!/bin/bash
#SBATCH --job-name=ML_Training
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=slurm-ml-%j.out

# Load the required environment (e.g., a virtualenv environment with PyTorch/TensorFlow)
source my_ml_env/activate  # Replace with the name of your virtualenv environment

# Define parameters for the training script
EPOCHS=20
LEARNING_RATE=0.0005
BATCH_SIZE=64

# Define the output file name, including the Slurm Job ID for uniqueness
OUTPUT_FILE="results/training_run_${SLURM_JOB_ID}.json"

# Create the output directory if it doesn't exist
mkdir -p results

# Run the Python script with the specified parameters and output file
python train_model.py \
    --epochs ${EPOCHS} \
    --learning-rate ${LEARNING_RATE} \
    --batch-size ${BATCH_SIZE} \
    --output-file ${OUTPUT_FILE}
```


### Example: Machine Learning Training with Singularity 🤖🐋

This is the recommended approach for running complex machine learning tasks. It combines the benefits of a self-contained environment (Singularity) with the power of the Slurm scheduler.

First, ensure your machine learning script, for example, `train_model.py`, is present inside your Singularity container. The script should be designed to accept command-line arguments.

Here is the `sbatch` script that will execute your `train_model.py` script from within the Singularity container, passing the required parameters.

```bash
#!/bin/bash
#SBATCH --job-name=ML_Singularity_Training
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=slurm-ml-singularity-%j.out

# Define the path to your Singularity image file on the cluster
# Ensure the image file contains your Python script and all dependencies
IMAGE_PATH="/path/to/my/ml_container.sif"

# Define parameters for the training script
# These parameters will be passed as arguments to your Python script
EPOCHS=20
LEARNING_RATE=0.0005
BATCH_SIZE=64

# Use 'singularity exec' to run a command inside the container
# The '--nv' flag is essential for exposing the GPU to the container
# The '/bin/bash -c "..."' part allows you to run a multi-line command
singularity exec --nv "$IMAGE_PATH" /bin/bash -c "
    echo 'Executing ML training script inside the container...'

    # The paths inside the container might be different from the host paths.
    # Specify the full path to your script as it exists *inside* the container.
    python /opt/my_ml_project/train_model.py \
        --epochs ${EPOCHS} \
        --learning-rate ${LEARNING_RATE} \
        --batch-size ${BATCH_SIZE}

    echo 'Training script finished. 🎉'
"
```

### Example: Iterating over JSON Configuration Files ⚙️

For a parameter sweep or running multiple experiments, a common practice is to have a directory of JSON files, where each file contains the configuration for a single training run.

Let's assume you have a directory named `configs/` with JSON files like this:

`configs/exp_01.json`

```json
{
  "epochs": 100,
  "learning_rate": 0.001,
  "batch_size": 32,
  "model_name": "resnet18"
}
```

`configs/exp_02.json`

```json
{
  "epochs": 50,
  "learning_rate": 0.0001,
  "batch_size": 64,
  "model_name": "resnet50"
}
```

Your Python training script (`train_model.py`) should be modified to accept a single argument: the path to the JSON file.

```python
import argparse
import json
#... other imports

def train_model(config_file):
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    print("Training with the following configuration:")
    print(json.dumps(config, indent=2))
    
    epochs = config['epochs']
    learning_rate = config['learning_rate']
    batch_size = config['batch_size']
    model_name = config['model_name']
    
    # Your training logic using these variables
    # ...
    
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("config_file", help="Path to the JSON configuration file")
    args = parser.parse_args()
    
    train_model(args.config_file)
```

Now, you can create a loop in your `sbatch` script to submit a separate job for each configuration file. A simple `for` loop is a straightforward way to achieve this.

```bash
#!/bin/bash
# A simple loop to submit multiple jobs

CONFIGS_DIR="./configs"

# Loop through all .json files in the configs directory
for config_file in ${CONFIGS_DIR}/*.json; do
    echo "Submitting job for config file: ${config_file}"
    
    # Use sbatch to submit a new job for each file
    # The --wrap option is a convenient way to run a single command without a separate script file
    # We pass the config file path as an argument to the python script
    sbatch --job-name="ML_$(basename ${config_file} .json)" \
           --partition=gpu \
           --nodes=1 \
           --gres=gpu:1 \
           --cpus-per-task=4 \
           --mem=16G \
           --time=04:00:00 \
           --output="slurm-$(basename ${config_file} .json)-%j.out" \
           --wrap="singularity exec --nv /path/to/my/ml_container.sif python /opt/my_ml_project/train_model.py ${config_file}"
done

echo "All jobs submitted. Check squeue to monitor their status."
```

#### Explanation of the Script:

  * **`for config_file in ${CONFIGS_DIR}/*.json; do`**: This bash loop iterates over every file ending with `.json` in the `./configs` directory.
  * **`sbatch --wrap="..."`**: This is a powerful feature that allows you to submit a job containing a single command without needing to create an intermediate job script file.
  * **`--job-name="ML_$(basename ${config_file} .json)"`**: This dynamically sets a unique job name for each run based on the JSON filename (e.g., `ML_exp_01`).
  * **`--output="..."`**: This dynamically creates unique output files for each job, preventing logs from being overwritten.
  * **`singularity exec --nv ... train_model.py ${config_file}`**: The path to the current JSON file from the loop is passed as an argument to the Python script inside the container.

#### Submission

To submit all the jobs defined by your JSON files, you only need to run the `sbatch` script itself:

```bash
sbatch submit_all_jobs.sh
```

A job ID will be returned for each submitted job. You can then use `squeue` to monitor all of your training runs. Happy computing\! 🥳

-----

# LPS page:

Back to the [main](https://sites.google.com/lps.ufrj.br/lps/início) page!
