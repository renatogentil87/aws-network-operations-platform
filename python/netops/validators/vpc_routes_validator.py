"""
VPC Routes Validator — Checks all VPCs in an account have 0.0.0.0/0 → TGW.

Usage:
    python -m netops.validators.vpc_routes_validator --account-id 123456789012 --region eu-west-1
"""

import argparse
from netops.collectors.vpc_routes_collector import get_all_route_tables


def validate(account_id, region="eu-west-1"):
    """
    Check every route table in every VPC for a default route to TGW.
    """

    print(f"\nValidating VPC routes in account {account_id} ({region})...")
    print("=" * 60)

    route_tables = get_all_route_tables(account_id=account_id, region=region)

    results = []

    for rt in route_tables:
        # Get route table name
        rt_name = "unnamed"
        for tag in rt.get("Tags", []):
            if tag["Key"] == "Name":
                rt_name = tag["Value"]

        # Get the VPC this route table belongs to
        vpc_id = rt["VpcId"]

        # Check if 0.0.0.0/0 → TGW exists
        has_default_to_tgw = False
        for route in rt.get("Routes", []):
            if route.get("DestinationCidrBlock") == "0.0.0.0/0" and route.get("TransitGatewayId"):
                has_default_to_tgw = True
                break

        results.append({
            "vpc_id": vpc_id,
            "route_table": rt_name,
            "route_table_id": rt["RouteTableId"],
            "has_default_to_tgw": has_default_to_tgw,
        })

    # Print results
    passed = 0
    failed = 0

    for r in results:
        if r["has_default_to_tgw"]:
            print(f"  ✅ PASS  {r['route_table']} ({r['route_table_id']}) in {r['vpc_id']}")
            passed += 1
        else:
            print(f"  ❌ FAIL  {r['route_table']} ({r['route_table_id']}) in {r['vpc_id']}")
            failed += 1

    # Summary
    print("=" * 60)
    print(f"Results: {passed} passed, {failed} failed, {len(results)} total")

    if failed == 0:
        print("✅ All route tables have default route to TGW")
    else:
        print("❌ Some route tables are missing default route to TGW")

    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Validate VPC routes have default to TGW")
    parser.add_argument("--account-id", required=True, help="AWS account ID to validate")
    parser.add_argument("--region", default="eu-west-1", help="AWS region")

    args = parser.parse_args()
    validate(account_id=args.account_id, region=args.region)
