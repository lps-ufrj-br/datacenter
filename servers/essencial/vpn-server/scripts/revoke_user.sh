

client_name=$1

# Get the last part of the current working directory
current_dir="${PWD##*/}"
# Check if the current directory is named 'scripts'
if [ "$current_dir" != "scripts" ]; then
    echo "Error: This script must be run from the 'scripts' directory."
    exit 1
fi

# Keep the corresponding crt, key and req files.
docker-compose -f ../files/docker-compose.yaml run --rm openvpn ovpn_revokeclient $client_name
# Remove the corresponding crt, key and req files.
docker-compose -f ../files/docker-compose.yaml run --rm openvpn ovpn_revokeclient $client_name remove
