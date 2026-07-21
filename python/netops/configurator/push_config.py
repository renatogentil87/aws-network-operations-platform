"""
Push Config - Renders Jinja2 templates and pushes to routers via telnet.

Usage:
    python -m netops.configurator.push_config --router R13 --template mpls_base.j2
    python -m netops.configurator.push_config --all --template mpls_base.j2
    python -m netops.configurator.push_config --router R8 --template pe_vrf.j2 --dry-run
"""

import argparse
import yaml
from pathlib import Path
from jinja2 import Template
from netmiko import ConnectHandler

BASE_DIR = Path(__file__).parent
INVENTORY_FILE = BASE_DIR / "inventory.yaml"
TEMPLATES_DIR = BASE_DIR / "templates"


def configure_router(router_name, router_vars, template_name, dry_run=False):
    port = router_vars["port"]
    print(f"\nConfiguring {router_name} (port {port})...")

    # connect to router
    connection = ConnectHandler(
        device_type="cisco_ios_telnet",
        host="localhost",
        port=port,
        username="",
        password="",
    )

    # get interfaces from the router
    output = connection.send_command("show ip interface brief")
    interfaces = []
    for line in output.splitlines()[1:]:
        parts = line.split()
        if parts and not parts[0].startswith("Loopback"):
            interfaces.append(parts[0])

    # read and render template
    template_file = TEMPLATES_DIR / template_name
    with open(template_file) as f:
        template = Template(f.read())

    router_vars["hostname"] = router_name
    router_vars["interfaces"] = interfaces
    config_text = template.render(router_vars)

    # build list of commands to push
    config_lines = []
    for line in config_text.splitlines():
        if line.strip() and not line.startswith("!"):
            config_lines.append(line)

    # dry run just prints, otherwise push to router
    if dry_run:
        print(f"\n--- {router_name} DRY RUN ---")
        for line in config_lines:
            print(f"  {line}")
        print("--- end ---\n")
        connection.disconnect()
    else:
        connection.send_config_set(config_lines, cmd_verify=False)
        connection.disconnect()
        print(f"done {router_name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--router", help="Router name, e.g. R13")
    parser.add_argument("--all", action="store_true", help="Configure all routers")
    parser.add_argument("--template", required=True, help="Template file, e.g. mpls_base.j2")
    parser.add_argument("--dry-run", action="store_true", help="Print config without pushing")
    args = parser.parse_args()

    with open(INVENTORY_FILE) as f:
        routers = yaml.safe_load(f)["routers"]

    if args.router:
        configure_router(args.router, routers[args.router], args.template, args.dry_run)
    elif args.all:
        for name, router_vars in routers.items():
            configure_router(name, router_vars, args.template, args.dry_run)
    else:
        print("Use --router R13 or --all")
