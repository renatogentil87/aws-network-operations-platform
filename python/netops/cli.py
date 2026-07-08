"""
NetOps CLI — Hybrid Network Operations Platform

YOUR TASK:
Build a CLI using the 'click' library that provides these commands:
    netops validate routes --region eu-west-1
    netops validate bgp --region eu-west-1 --device router-edge1
    netops validate vpn --region eu-west-1
    netops validate isolation --region eu-west-1
    netops collect aws --region eu-west-1
    netops collect device --host router-edge1
    netops collect hybrid --region eu-west-1 --device router-edge1
    netops report health --format html

STRUCTURE:
- Use @click.group() for the top-level 'netops' command
- Use nested @click.group() for 'validate', 'collect', 'remediate', 'report'
- Each subcommand imports from the respective module (validators/, collectors/, etc.)

REFERENCE:
- click docs: https://click.palletsprojects.com/en/8.1.x/
- Pattern: lazy imports inside the command function (not at top of file)

EXAMPLE (one command fully implemented for reference):
"""
import click


@click.group()
def main():
    """Hybrid Network Operations Platform — validate, collect, remediate, report."""
    pass


@main.group()
def validate():
    """Validate network state against desired configuration."""
    pass


@main.group()
def collect():
    """Collect current state from AWS and on-prem devices."""
    pass


@main.group()
def remediate():
    """Execute remediation actions."""
    pass


@main.group()
def report():
    """Generate network health reports."""
    pass


# ✅ COMPLETE EXAMPLE — one validate command fully implemented as reference
@validate.command("routes")
@click.option("--region", default="eu-west-1", help="AWS region")
@click.option("--desired-state", default="desired-state/desired-routes-tgw.yaml", help="Path to desired state YAML")
def validate_routes(region, desired_state):
    """Validate TGW route tables match desired state."""
    from netops.validators.tgw_routes import validate_tgw_routes
    validate_tgw_routes(region=region, desired_state_path=desired_state)


# TODO: Add validate bgp command
# TODO: Add validate vpn command
# TODO: Add validate isolation command
# TODO: Add collect aws command
# TODO: Add collect device command
# TODO: Add collect hybrid command
# TODO: Add report health command


if __name__ == "__main__":
    main()
