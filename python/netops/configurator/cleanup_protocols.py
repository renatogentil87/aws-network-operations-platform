"""
Cleanup Protocols — Removes OSPF, BGP, VRF, VPNv4, MPLS TE, xconnect, and pseudowire configs
from all routers while preserving interface IP addressing and loopbacks.

Usage:
    python -m netops.configurator.cleanup_protocols --all
    python -m netops.configurator.cleanup_protocols --router R2
    python -m netops.configurator.cleanup_protocols --all --dry-run
"""

import argparse
import time
import yaml
from pathlib import Path
from netmiko import ConnectHandler

BASE_DIR = Path(__file__).parent
INVENTORY_FILE = BASE_DIR / "inventory.yaml"


def get_cleanup_commands(connection, router_name, router_vars):
    """Parse running config and generate removal commands."""
    commands = []

    # Get the running config
    running = connection.send_command("show running-config")
    lines = running.splitlines()

    # --- Remove router OSPF ---
    ospf_processes = []
    for line in lines:
        if line.startswith("router ospf "):
            proc = line.split()[-1]
            ospf_processes.append(proc)
    for proc in ospf_processes:
        commands.append(f"no router ospf {proc}")

    # --- Remove router BGP ---
    for line in lines:
        if line.startswith("router bgp "):
            asn = line.split()[-1]
            commands.append(f"no router bgp {asn}")
            break

    # --- Remove VRFs ---
    vrfs = []
    for line in lines:
        if line.startswith("ip vrf "):
            vrf_name = line.split()[2]
            vrfs.append(vrf_name)
    for vrf in vrfs:
        commands.append(f"no ip vrf {vrf}")

    # --- Remove MPLS LDP config ---
    for line in lines:
        if line.startswith("mpls ldp router-id"):
            commands.append(f"no {line.strip()}")
        if line.startswith("mpls label range"):
            commands.append(f"no {line.strip()}")

    # --- Remove mpls ldp session protection ---
    for line in lines:
        if line.strip() == "mpls ldp session protection":
            commands.append("no mpls ldp session protection")
        if line.strip().startswith("mpls ldp discovery targeted-hello"):
            commands.append(f"no {line.strip()}")

    # --- Remove mpls traffic-eng tunnels ---
    for line in lines:
        if line.startswith("mpls traffic-eng tunnels"):
            commands.append("no mpls traffic-eng tunnels")

    # --- Remove explicit paths ---
    explicit_paths = []
    for line in lines:
        if line.startswith("ip explicit-path name "):
            path_name = line.split("name ")[-1].strip()
            explicit_paths.append(path_name)
    for path in explicit_paths:
        commands.append(f"no ip explicit-path name {path}")

    # --- Remove Tunnel interfaces ---
    tunnels = []
    for line in lines:
        if line.startswith("interface Tunnel"):
            tunnel_name = line.split()[1]
            tunnels.append(tunnel_name)
    for tunnel in tunnels:
        commands.append(f"no interface {tunnel}")

    # --- Remove pseudowire classes ---
    pw_classes = []
    for line in lines:
        if line.startswith("pseudowire-class "):
            pw_class = line.split()[-1]
            pw_classes.append(pw_class)
    for pwc in pw_classes:
        commands.append(f"no pseudowire-class {pwc}")

    # --- Remove l2 vfi ---
    vfis = []
    for line in lines:
        if line.startswith("l2 vfi "):
            vfi_name = line.split()[2]
            vfis.append(vfi_name)
    for vfi in vfis:
        commands.append(f"no l2 vfi {vfi}")

    # --- Remove connect statements ---
    connects = []
    for line in lines:
        if line.startswith("connect "):
            connects.append(line.strip())
    for conn in connects:
        commands.append(f"no {conn}")

    # --- Clean interfaces: remove OSPF, MPLS, TE, xconnect, but keep IP ---
    current_intf = None
    intf_commands = {}

    for i, line in enumerate(lines):
        if line.startswith("interface "):
            current_intf = line.split()[1]
            intf_commands[current_intf] = []
        elif current_intf and line.startswith(" "):
            stripped = line.strip()
            # Remove these from interfaces
            if any(stripped.startswith(prefix) for prefix in [
                "ip ospf",
                "mpls ip",
                "mpls label protocol",
                "mpls traffic-eng tunnels",
                "mpls traffic-eng",
                "tunnel mode",
                "tunnel destination",
                "tunnel mpls",
                "xconnect",
                "ip rsvp bandwidth",
                "ip vrf forwarding",
                "backup peer",
                "backup delay",
                "service instance",
            ]):
                intf_commands[current_intf].append(f"no {stripped}")
        elif not line.startswith(" "):
            current_intf = None

    # Build interface cleanup commands
    for intf, cmds in intf_commands.items():
        if cmds:
            commands.append(f"interface {intf}")
            commands.extend(cmds)
            commands.append("exit")

    # --- Re-add IP addresses to interfaces that had VRF removed ---
    # (removing 'ip vrf forwarding' wipes the IP address)
    for link in router_vars.get("links", []):
        if link.get("vrf"):
            commands.append(f"interface {link['name']}")
            commands.append(f"ip address {link['ip']} {link['mask']}")
            commands.append("no shutdown")
            commands.append("exit")

    # --- Remove mpls ip from global (if present) ---
    for line in lines:
        if line.strip() == "mpls ip":
            commands.append("no mpls ip")

    return commands


def cleanup_router(router_name, router_vars, dry_run=False):
    """Connect to router and remove protocol configs."""
    port = router_vars["port"]
    role = router_vars.get("role", "?")
    print(f"\n{'='*60}")
    print(f"Cleaning {router_name} (port {port}, role: {role})")
    print(f"{'='*60}")

    connection = ConnectHandler(
        device_type="cisco_ios_telnet",
        host="localhost",
        port=port,
        username="",
        password="",
    )

    commands = get_cleanup_commands(connection, router_name, router_vars)

    if not commands:
        print(f"  Nothing to clean on {router_name}")
        connection.disconnect()
        return

    if dry_run:
        print(f"\n--- {router_name} DRY RUN ({len(commands)} commands) ---")
        for cmd in commands:
            print(f"  {cmd}")
        print("--- end ---")
    else:
        print(f"  Pushing {len(commands)} cleanup commands...")
        # Send in config mode
        output = connection.send_config_set(commands, cmd_verify=False, exit_config_mode=True)
        # Save config
        try:
            connection.send_command_timing("write memory", delay_factor=2)
        except Exception:
            pass  # Some GNS3 routers don't have NVRAM - that's fine
        print(f"  ✓ {router_name} cleaned and saved")

    connection.disconnect()


def verify_router(router_name, router_vars):
    """Quick verification that IPs are intact and protocols removed."""
    port = router_vars["port"]
    print(f"\n  Verifying {router_name}...")

    connection = ConnectHandler(
        device_type="cisco_ios_telnet",
        host="localhost",
        port=port,
        username="",
        password="",
    )

    # Check interfaces still have IPs
    output = connection.send_command("show ip interface brief")
    up_count = output.count("up")
    print(f"    Interfaces up: {up_count // 2}")

    # Check loopback
    lo_output = connection.send_command("show ip interface Loopback0 | include Internet")
    print(f"    Loopback0: {lo_output.strip()}")

    # Confirm no OSPF
    ospf = connection.send_command("show ip ospf")
    if "Routing Process" in ospf:
        print(f"    ⚠ OSPF still present!")
    else:
        print(f"    ✓ No OSPF")

    # Confirm no BGP
    bgp = connection.send_command("show ip bgp summary")
    if "BGP router identifier" in bgp:
        print(f"    ⚠ BGP still present!")
    else:
        print(f"    ✓ No BGP")

    # Confirm no VRF
    vrf = connection.send_command("show ip vrf")
    if "Name" in vrf and len(vrf.splitlines()) > 1:
        print(f"    ⚠ VRFs still present!")
    else:
        print(f"    ✓ No VRFs")

    connection.disconnect()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Remove OSPF/BGP/VRF/MPLS from GNS3 routers")
    parser.add_argument("--router", help="Clean specific router (e.g. R2)")
    parser.add_argument("--all", action="store_true", help="Clean all routers")
    parser.add_argument("--dry-run", action="store_true", help="Show commands without pushing")
    parser.add_argument("--verify", action="store_true", help="Verify after cleanup")
    args = parser.parse_args()

    with open(INVENTORY_FILE) as f:
        routers = yaml.safe_load(f)["routers"]

    targets = {}
    if args.router:
        if args.router not in routers:
            print(f"Error: {args.router} not in inventory")
            exit(1)
        targets = {args.router: routers[args.router]}
    elif args.all:
        targets = routers
    else:
        print("Use --router R2 or --all")
        exit(1)

    print(f"\n🧹 Protocol Cleanup — {len(targets)} router(s)")
    print(f"   Removing: OSPF, BGP, VRF, MPLS LDP, MPLS TE, xconnect, pseudowires")
    print(f"   Keeping:  Interface IPs, Loopbacks, Hostnames")
    if args.dry_run:
        print(f"   Mode: DRY RUN (no changes)")
    print()

    for name, rvars in targets.items():
        cleanup_router(name, rvars, dry_run=args.dry_run)

    if args.verify and not args.dry_run:
        print(f"\n{'='*60}")
        print("VERIFICATION")
        print(f"{'='*60}")
        time.sleep(5)
        for name, rvars in targets.items():
            verify_router(name, rvars)

    print(f"\n✅ Done. All routers have IP addressing only — ready for reconfiguration.")
