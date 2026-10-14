import os, sys
import subprocess

# Define the command to execute
command = ["getent", "passwd"]  # Example: list files in long format

try:
    # Execute the command and capture output
    # capture_output=True captures stdout and stderr
    # text=True decodes the output as text (UTF-8 by default)
    result = subprocess.run(command, capture_output=True, text=True, check=True)

    # Split the captured standard output into lines
    output_lines = result.stdout.splitlines()


except subprocess.CalledProcessError as e:
    # Handle errors if the command returns a non-zero exit code
    print(f"Error executing command: {e}")
    print(f"Stderr: {e.stderr}")
    sys.exit(1)

for line in output_lines:
    parts = line.split(":")
    if parts[1]=="*":
        username = parts[0]
        command = f"sudo singularity config fakeroot --add {username}"
        print(command)
        os.system(command)
