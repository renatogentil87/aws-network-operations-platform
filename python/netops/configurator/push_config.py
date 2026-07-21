"""
Push Config — Renders Jinja2 templates and pushes to routers via telnet.

Usage:
    python -m netops.configurator.push_config --router R13 --template mpls_base.j2
    python -m netops.configurator.push_config --all --template mpls_base.j2
"""

import argparse
import yaml
from pathlib import Path
from jinja2 import Template
from netmiko import ConnectHandler


# File locations
BASE_DIR = Path(__file__).parent
INVENTORY_FILE = BASE_DIR / "inventory.yaml"
TEMPLATES_DIR = BASE_DIR / "templates"


def configure_router(router_name, router_vars, template_name, dry_run=False):
    """Connect to a router, render a template, push the config."""

    port = router_vars["port"]
    print(f"\nConfiguring {router_name} (port {port})...")

    # Step 1: Connect to the router
    connection = ConnectHandler(
        device_type="cisco_ios_telnet",
        host="localhost",
        port=port,
        username="",
        password="",
    )

    # Step 2: Get the router's interfaces
    output = connection.send_command("show ip interface brief")
    interfaces = []
    for line in output.splitlines()[1:]:
        parts = line.split()
        if parts and not parts[0].startswith("Loopback"):
            interfaces.append(parts[0])

    # Step 3: Read the template file
    template_file = TEMPLATES_DIR / template_name
    with open(template_file) as f:
        template = Template(f.read())

    # Step 4: Render the template with variables
    router_vars["hostname"] = router_name
    router_vars["interfaces"] = interfaces
    config_text = template.render(router_vars)

    # Step 5: Convert to a list of commands (skip empty lines and comments)
    config_lines = []
    for line in config_text.splitlines():
        if line.strip() and not line.startswith("!"):
            config_lines.append(line)

    # Step 6: Dry run = print only, otherwise push
    if dry_run:
        print(f"\n--- Config for {router_name} (DRY RUN - not pushed) ---")
        for line in config_lines:
            print(f"  {line}")
        print(f"--- End ---\n")
        connection.disconnect()
    else:
        connection.send_config_set(config_lines, cmd_verify=False)
        connection.disconnect()
        print(f" {router_name} done")


# --- Main ---

parser = argparse.ArgumentParser()
parser.add_argument("--router", help="Router name, e.g. R13")
parser.add_argument("--all", action="store_true", help="Configure all routers")
parser.add_argument("--template", required=True, help="Template file, e.g. mpls_base.j2")
parser.add_argument("--dry-run", action="store_true", help="Print the config without pushing it")
args = parser.parse_args()

# Load inventory
with open(INVENTORY_FILE) as f:
    routers = yaml.safe_load(f)["routers"]

# Run
if args.router:
    configure_router(args.router, routers[args.router], args.template, args.dry_run)
elif args.all:
    for name, vars in routers.items():
        configure_router(name, vars, args.template, args.dry_run)
else:
    print("Use --router R13 or --all")
