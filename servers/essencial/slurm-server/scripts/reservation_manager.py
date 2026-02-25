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

def create_reservation(args):
    """Create a Slurm reservation."""
    cmd = [
        "sudo", "scontrol", "create", "reservation",
        f"ReservationName={args.name}",
        f"StartTime={args.starttime}",
        f"Duration={args.duration}",
        f"Nodes={args.nodes}",
        f"Users={args.users}"
    ]
    
    if args.flags:
        cmd.append(f"Flags={args.flags}")
        
    if run_command(cmd):
        print(f"Reservation '{args.name}' created successfully.")
    else:
        print(f"Failed to create reservation '{args.name}'.")

def delete_reservation(args):
    """Delete a Slurm reservation."""
    cmd = [
        "sudo", "scontrol", "delete", f"ReservationName={args.name}"
    ]
    
    if run_command(cmd):
        print(f"Reservation '{args.name}' deleted successfully.")
    else:
        print(f"Failed to delete reservation '{args.name}'.")

def main():
    parser = argparse.ArgumentParser(description="Manage Slurm Reservations")
    subparsers = parser.add_subparsers(dest="command", help="Sub-command to run")
    
    # Create sub-command
    create_parser = subparsers.add_parser("create", help="Create a reservation")
    create_parser.add_argument("--name", "-n", required=True, help="Name of the reservation")
    create_parser.add_argument("--nodes", "-N", required=True, help="Nodes to include (e.g., caloba[10-12])")
    create_parser.add_argument("--users", "-u", required=True, help="Users allowed (e.g., user1,user2)")
    create_parser.add_argument("--duration", "-d", default="UNLIMITED", help="Duration of the reservation (default: UNLIMITED)")
    create_parser.add_argument("--starttime", "-s", default="now", help="Start time of the reservation (default: now)")
    create_parser.add_argument("--flags", "-f", help="Additional flags for the reservation")
    
    # Delete sub-command
    delete_parser = subparsers.add_parser("delete", help="Delete a reservation")
    delete_parser.add_argument("--name", "-n", required=True, help="Name of the reservation to delete")
    
    args = parser.parse_args()
    
    if args.command == "create":
        create_reservation(args)
    elif args.command == "delete":
        delete_reservation(args)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
