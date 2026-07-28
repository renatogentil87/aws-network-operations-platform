"""
Push Config - Renders Jinja2 templates and pushes to routers via telnet.
Selects the template based on the router role (P, PE, CE) from inventory.

Usage:
    python -m netops.configurator.push_config --router R13 --template mpls_base.j2
    python -m netops.configurator.push_config --role P
    python -m netops.configurator.push_config --role PE --dry-run
    python -m netops.configurator.push_config --all --template mpls_base.j2 --dry-run
"""

import argparse
import time
import yaml
from pathlib import Path
from jinja2 import Template
from netmiko import ConnectHandler

BASE_DIR = Path(__file__).parent
INVENTORY_FILE = BASE_DIR / "inventory.yaml"
TEMPLATES_DIR = BASE_DIR / "templates"

# default template per role
ROLE_TEMPLATES = {
    "P": "mpls_base.j2",
    "PE": "pe_vrf.j2",
    "CE": "ce_router.j2",
}


def configure_router(router_name, router_vars, template_name, dry_run=False):
    port = router_vars["port"]
    print(f"\nConfiguring {router_name} (port {port}, role: {router_vars.get('role', '?')})...")

    # connect to router
    connection = ConnectHandler(
        device_type="cisco_ios_telnet",
        host="localhost",
        port=port,
        username="",
        password="",
    )

    # get interfaces from the router (skip loopbacks and tunnels)
    output = connection.send_command("show ip interface brief")
    interfaces = []
    for line in output.splitlines()[1:]:
        parts = line.split()
        if parts and not parts[0].startswith("Loopback") and not parts[0].startswith("Tunnel"):
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
        print(f"config pushed to {router_name}")

        # wait for protocols to converge then verify
        print("  waiting 30s for convergence...")
        time.sleep(30)

        print("  checking OSPF neighbors...")
        ospf = connection.send_command("show ip ospf neighbor")
        for line in ospf.splitlines():
            if "FULL" in line or "Neighbor" in line:
                print(f"    {line.strip()}")

        print("  checking LDP neighbors...")
        ldp = connection.send_command("show mpls ldp neighbor")
        for line in ldp.splitlines():
            if "Peer LDP" in line or "Up time" in line:
                print(f"    {line.strip()}")

        connection.disconnect()
        print(f"done {router_name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--router", help="Router name, e.g. R13")
    parser.add_argument("--role", help="Configure all routers with this role (P, PE, CE)")
    parser.add_argument("--all", action="store_true", help="Configure all routers")
    parser.add_argument("--template", help="Template file (optional, auto-selected by role)")
    parser.add_argument("--dry-run", action="store_true", help="Print config without pushing")
    args = parser.parse_args()

    with open(INVENTORY_FILE) as f:
        routers = yaml.safe_load(f)["routers"]

    if args.router:
        router_vars = routers[args.router]
        template = args.template or ROLE_TEMPLATES.get(router_vars.get("role"), "mpls_base.j2")
        configure_router(args.router, router_vars, template, args.dry_run)
    elif args.role:
        template = args.template or ROLE_TEMPLATES.get(args.role, "mpls_base.j2")
        for name, router_vars in routers.items():
            if router_vars.get("role") == args.role:
                configure_router(name, router_vars, template, args.dry_run)
    elif args.all:
        for name, router_vars in routers.items():
            template = args.template or ROLE_TEMPLATES.get(router_vars.get("role"), "mpls_base.j2")
            configure_router(name, router_vars, template, args.dry_run)
    else:
        print("Use --router R13, --role P, or --all")
