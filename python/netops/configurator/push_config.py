"""
Push Config — Reads inventory, renders Jinja2 templates, pushes config via telnet.

Usage:
    python -m netops.configurator.push_config --router R13 --template mpls_base.j2
    python -m netops.configurator.push_config --all --template mpls_base.j2
"""

import argparse
import yaml
from pathlib import Path
from jinja2 import Template
from netmiko import ConnectHandler


# Paths
BASE_DIR = Path(__file__).parent
INVENTORY_FILE = BASE_DIR / "inventory.yaml"
TEMPLATES_DIR = BASE_DIR / "templates"


def load_inventory():
    """Load the router inventory from YAML."""
    with open(INVENTORY_FILE) as f:
        return yaml.safe_load(f)["routers"]


def get_router_interfaces(host, port):
    """Connect to a router and discover its interfaces."""
    device = {
        "device_type": "cisco_ios_telnet",
        "host": host,
        "port": port,
        "username": "",
        "password": "",
    }
    connection = ConnectHandler(**device)
    output = connection.send_command("show ip interface brief")
    connection.disconnect()

    # Parse interfaces (skip Loopback, only get physical interfaces)
    interfaces = []
    for line in output.splitlines()[1:]:  # skip header
        parts = line.split()
        if parts and not parts[0].startswith("Loopback"):
            interfaces.append(parts[0])
    return interfaces


def render_template(template_name, variables):
    """Render a Jinja2 template with the given variables."""
    template_path = TEMPLATES_DIR / template_name
    with open(template_path) as f:
        template = Template(f.read())
    return template.render(**variables)


def push_config(host, port, config_lines):
    """Push configuration to a router via telnet."""
    device = {
        "device_type": "cisco_ios_telnet",
        "host": host,
        "port": port,
        "username": "",
        "password": "",
    }
    connection = ConnectHandler(**device)
    output = connection.send_config_set(config_lines, cmd_verify=False)
    connection.disconnect()
    return output


def configure_router(router_name, router_vars, template_name):
    """Full workflow: discover interfaces, render template, push config."""
    port = router_vars["port"]

    print(f"\n{'='*60}")
    print(f"Configuring {router_name} (port {port})")
    print(f"{'='*60}")

    # Discover interfaces
    print(f"  Discovering interfaces...")
    interfaces = get_router_interfaces("localhost", port)
    print(f"  Found: {interfaces}")

    # Build template variables
    variables = {
        "hostname": router_name,
        "loopback": router_vars["loopback"],
        "ospf_area": router_vars["ospf_area"],
        "interfaces": interfaces,
    }

    # Render template
    config_text = render_template(template_name, variables)
    print(f"  Rendered config:")
    for line in config_text.splitlines():
        if line.strip() and not line.startswith("!"):
            print(f"    {line}")

    # Convert to list of commands (skip empty lines and comments)
    config_lines = [
        line for line in config_text.splitlines()
        if line.strip() and not line.startswith("!")
    ]

    # Push config
    print(f"  Pushing config...")
    output = push_config("localhost", port, config_lines)
    print(f"  ✅ Done")

    return output


def main():
    parser = argparse.ArgumentParser(description="Push config to GNS3 routers")
    parser.add_argument("--router", help="Router name (e.g., R13)")
    parser.add_argument("--all", action="store_true", help="Configure all routers")
    parser.add_argument("--template", required=True, help="Template file name (e.g., mpls_base.j2)")

    args = parser.parse_args()

    inventory = load_inventory()

    if args.router:
        if args.router not in inventory:
            print(f"Error: {args.router} not found in inventory")
            return
        configure_router(args.router, inventory[args.router], args.template)

    elif args.all:
        for router_name, router_vars in inventory.items():
            configure_router(router_name, router_vars, args.template)

    else:
        print("Error: specify --router <name> or --all")


if __name__ == "__main__":
    main()
