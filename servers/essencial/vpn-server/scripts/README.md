# OpenVPN User Management Scripts

This directory contains utility shell scripts to manage OpenVPN client certificates and user access using the Dockerized OpenVPN service (`kylemanna/openvpn`).

---

## Prerequisites

- All scripts **must be executed from within this `scripts` directory**:
  ```bash
  cd servers/essencial/vpn-server/scripts
  ```
- Docker and `docker-compose` must be installed and running on the host server.
- The OpenVPN PKI must be initialized and the container configuration in `../files/docker-compose.yaml` must be accessible.

---

## Available Scripts

### 1. `create_user.sh`

Creates a new OpenVPN client certificate without a passphrase and exports the complete client profile (`.ovpn`).

- **Usage**:
  ```bash
  ./create_user.sh <client_name>
  ```
- **Example**:
  ```bash
  ./create_user.sh user1
  ```
- **Output**:
  Generates `<client_name>.ovpn` in the current directory, containing the embedded certificates and keys required for the client to connect.

---

### 2. `list_users.sh`

Lists all registered OpenVPN client certificates, their validity timeframe, and their current status (`VALID`, `REVOKED`, `EXPIRED`).

- **Usage**:
  ```bash
  ./list_users.sh [options]
  ```
- **Options**:
  - `-h`, `--help`: Display the help message.
- **Example**:
  ```bash
  ./list_users.sh
  ```
- **Output Format**:
  Displays a CSV/table format with client details:
  ```csv
  name,begin,end,status
  user1,Oct 14 12:00:00 2026 GMT,Oct 14 12:00:00 2027 GMT,VALID
  user2,Jan 01 10:00:00 2026 GMT,Jan 01 10:00:00 2027 GMT,REVOKED
  ```

---

### 3. `revoke_user.sh`

Revokes an existing OpenVPN client certificate and removes the certificate files from the PKI database.

- **Usage**:
  ```bash
  ./revoke_user.sh <client_name>
  ```
- **Example**:
  ```bash
  ./revoke_user.sh user1
  ```
- **Behavior**:
  1. Revokes the client certificate in the OpenVPN Certificate Revocation List (CRL).
  2. Removes the corresponding `.crt`, `.key`, and `.req` files from the PKI storage.

---

## Summary Table

| Script | Purpose | Command Example |
|---|---|---|
| [`create_user.sh`](create_user.sh) | Generate certificate and export `.ovpn` file | `./create_user.sh john_doe` |
| [`list_users.sh`](list_users.sh) | List all client certificates and statuses | `./list_users.sh` |
| [`revoke_user.sh`](revoke_user.sh) | Revoke client certificate and block access | `./revoke_user.sh john_doe` |
