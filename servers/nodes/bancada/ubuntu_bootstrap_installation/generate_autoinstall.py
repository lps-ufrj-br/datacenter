#!/usr/bin/env python3
"""
==============================================================================
LPS / UFRJ - Gerador de Arquivos de Autoinstall / Cloud-Init
==============================================================================
Lê o inventário (inventory.yaml) e gera os arquivos de configuração para cada
máquina de bancada, preparando os arquivos para:
  1. Pendrive Ventoy (dist/<hostname>.yaml e dist/ventoy.json)
  2. Partição NoCloud / HTTP (dist/<hostname>/user-data)
  3. Snippets do Proxmox VE (dist/<hostname>.yaml)
==============================================================================
"""

import os
import sys
import json
import re
from pathlib import Path

try:
    import yaml
except ImportError:
    yaml = None

try:
    import jinja2
except ImportError:
    jinja2 = None


def parse_simple_yaml(filepath: Path) -> dict:
    """Carrega o inventory.yaml."""
    if yaml is not None:
        with open(filepath, "r", encoding="utf-8") as f:
            return yaml.safe_load(f)

    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    data = {"common": {}, "nodes": []}
    current_section = None
    current_node = None

    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue

        if line == "common:":
            current_section = "common"
            continue
        elif line == "nodes:":
            current_section = "nodes"
            continue

        if current_section == "common":
            if ":" in line:
                k, v = line.split(":", 1)
                k = k.strip()
                v = v.strip().strip('"').strip("'")
                if v == "[]":
                    data["common"][k] = []
                elif v.isdigit():
                    data["common"][k] = int(v)
                else:
                    data["common"][k] = v
            elif line.startswith("-"):
                val = line.lstrip("- ").strip('"').strip("'")
                data["common"].setdefault("dns", []).append(val)

        elif current_section == "nodes":
            if line.startswith("- hostname:"):
                val = line.split(":", 1)[1].strip().strip('"').strip("'")
                current_node = {"hostname": val}
                data["nodes"].append(current_node)
            elif line.startswith("ip:") and current_node:
                val = line.split(":", 1)[1].strip().strip('"').strip("'")
                current_node["ip"] = val

    return data


def render_template(template_str: str, context: dict) -> str:
    """Renderiza o template usando Jinja2 ou substituição inteligente."""
    if jinja2 is not None:
        env = jinja2.Environment(loader=jinja2.BaseLoader())
        template = env.from_string(template_str)
        return template.render(**context)

    node = context.get("node", {})
    common = context.get("common", {})
    dns_list = common.get("dns", ["146.164.147.2", "8.8.8.8", "8.8.4.4"])
    dns_block = "\n".join([f"              - {d}" for d in dns_list])

    replacements = {
        "{{ node.hostname }}": node.get("hostname", ""),
        "{{ node.ip }}": node.get("ip", ""),
        "{{ common.admin_user }}": common.get("admin_user", "cluster"),
        "{{ common.admin_password_hash }}": common.get("admin_password_hash", ""),
        "{{ common.admin_realname }}": common.get("admin_realname", "LPS Cluster Admin"),
        "{{ common.netmask }}": str(common.get("netmask", 24)),
        "{{ common.gateway }}": common.get("gateway", "146.164.147.1"),
        "{{ common.domain }}": common.get("domain", "lps.ufrj.br"),
        "{{ common.dns_block }}": dns_block,
        "{{ common.kerberos_realm }}": common.get("kerberos_realm", "LPS.UFRJ.BR"),
        "{{ common.kerberos_server }}": common.get("kerberos_server", "auth-server.lps.ufrj.br"),
        "{{ common.ldap_server_uri }}": common.get("ldap_server_uri", "ldap://auth-server.lps.ufrj.br"),
        "{{ common.ldap_base_dn }}": common.get("ldap_base_dn", "dc=lps,dc=ufrj,dc=br"),
        "{{ common.nfs_marketplace }}": common.get("nfs_marketplace", "10.1.1.202:/volume1/market_place"),
        "{{ common.nfs_projects }}": common.get("nfs_projects", "10.1.1.204:/shares/projects"),
        "{{ common.nfs_homes }}": common.get("nfs_homes", "10.1.1.202:/volume1/homes"),
    }

    out = template_str

    # Trata bloco for de DNS
    dns_loop_pattern = r"{% for dns_ip in common\.dns %}\s*- {{ dns_ip }}\s*{% endfor %}"
    out = re.sub(dns_loop_pattern, dns_block.strip(), out)

    # Limpa tags condicionais
    out = re.sub(r"{% if.*?%}", "", out)
    out = re.sub(r"{% endif %}", "", out)
    out = re.sub(r"{% for.*?%}", "", out)
    out = re.sub(r"{% endfor %}", "", out)

    for k, v in replacements.items():
        out = out.replace(k, v)

    # Remove linhas vazias consecutivas
    out = re.sub(r"\n{3,}", "\n\n", out)
    return out


def main():
    base_dir = Path(__file__).resolve().parent
    inventory_path = base_dir / "inventory.yaml"
    template_path = base_dir / "templates" / "user-data.j2"
    dist_dir = base_dir / "dist"

    if not inventory_path.exists():
        print(f"❌ Erro: Inventário não encontrado em: {inventory_path}")
        sys.exit(1)

    if not template_path.exists():
        print(f"❌ Erro: Template não encontrado em: {template_path}")
        sys.exit(1)

    with open(template_path, "r", encoding="utf-8") as f:
        template_content = f.read()

    inventory = parse_simple_yaml(inventory_path)
    common = inventory.get("common", {})
    nodes = inventory.get("nodes", [])

    # Formata bloco de DNS para indentação no YAML
    dns_list = common.get("dns", ["146.164.147.2", "8.8.8.8", "8.8.4.4"])
    common["dns_block"] = "\n".join([f"              - {d}" for d in dns_list])

    if not nodes:
        print("⚠️  Aviso: Nenhum nó encontrado em inventory.yaml")
        sys.exit(0)

    dist_dir.mkdir(parents=True, exist_ok=True)

    print("==============================================================================")
    print(f"🚀 LPS Bancada - Gerando arquivos de Autoinstall para {len(nodes)} nós...")
    print("==============================================================================")

    ventoy_templates = []

    for node in nodes:
        hostname = node["hostname"]
        ip = node["ip"]
        context = {"node": node, "common": common, "nodes": nodes}

        rendered = render_template(template_content, context)

        # 1. Arquivo para Ventoy e Proxmox Snippet (dist/<hostname>.yaml)
        ventoy_file = dist_dir / f"{hostname}.yaml"
        with open(ventoy_file, "w", encoding="utf-8") as f:
            f.write(rendered)

        # 2. Pasta com estrutura NoCloud (dist/<hostname>/user-data e meta-data)
        node_dir = dist_dir / hostname
        node_dir.mkdir(exist_ok=True)
        with open(node_dir / "user-data", "w", encoding="utf-8") as f:
            f.write(rendered)
        with open(node_dir / "meta-data", "w", encoding="utf-8") as f:
            f.write(f"instance-id: {hostname}\nlocal-hostname: {hostname}\n")

        ventoy_templates.append(f"/ventoy/autoinstall/{hostname}.yaml")
        print(f"  ✅ [{hostname}] IP: {ip:<15} -> dist/{hostname}.yaml")

    # 3. Gerar ventoy.json
    ventoy_json_path = dist_dir / "ventoy.json"
    ventoy_data = {
        "auto_install": [
            {
                "image": "/ubuntu-24.04-live-server-amd64.iso",
                "template": ventoy_templates
            }
        ]
    }
    with open(ventoy_json_path, "w", encoding="utf-8") as f:
        json.dump(ventoy_data, f, indent=4)

    print("\n------------------------------------------------------------------------------")
    print(f"🎉 Concluído com sucesso! Arquivos gerados em: {dist_dir}")
    print(f"   • Menu do Ventoy: {ventoy_json_path}")
    print("==============================================================================")


if __name__ == "__main__":
    main()
