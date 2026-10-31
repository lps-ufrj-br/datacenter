#!/usr/bin/env python3
"""
==============================================================================
LPS / UFRJ - 08_configure_singularity.py
Configuração de Fakeroot para Usuários de Domínio (LDAP) no Singularity / Apptainer
==============================================================================
"""

import os
import sys
import subprocess
import shutil

def get_binary():
    if shutil.which("singularity"):
        return "singularity"
    elif shutil.which("apptainer"):
        return "apptainer"
    return None

def main():
    binary = get_binary()
    if not binary:
        print("⚠️ Nem apptainer nem singularity foram encontrados no PATH.")
        sys.exit(0)

    try:
        result = subprocess.run(["getent", "passwd"], capture_output=True, text=True, check=True)
        lines = result.stdout.splitlines()
    except subprocess.CalledProcessError as e:
        print(f"❌ Erro ao executar getent passwd: {e}")
        sys.exit(1)

    configured = 0
    print(f"🔧 Configurando permissões fakeroot ({binary})...")

    for line in lines:
        parts = line.split(":")
        if len(parts) < 3:
            continue

        username = parts[0]
        try:
            uid = int(parts[2])
        except ValueError:
            continue

        # Filtra contas regulares de usuários (UID entre 1000 e 60000)
        # Ignora contas especiais de sistema e 'nobody'
        if 1000 <= uid < 60000 and username != "nobody":
            cmd = ["sudo", binary, "config", "fakeroot", "--add", username]
            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0:
                print(f"  ✅ Fakeroot adicionado para: {username} (UID {uid})")
                configured += 1

    print(f"✨ Concluído: {configured} contas configuradas para fakeroot no {binary}.")

if __name__ == "__main__":
    main()
