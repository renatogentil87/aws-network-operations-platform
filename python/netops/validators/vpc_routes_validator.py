"""
VPC Routes Validator - Checks all VPCs in an account have 0.0.0.0/0 pointing to TGW.

Usage:
    python -m netops.validators.vpc_routes_validator --account-id 123456789012 --region eu-west-1
"""

import argparse
from netops.collectors.vpc_routes_collector import get_all_route_tables


def validate(account_id, region="eu-west-1"):
    print(f"\nValidating VPC routes in account {account_id} ({region})...")
    print("=" * 60)

    route_tables = get_all_route_tables(account_id=account_id, region=region)

    passed = 0
    failed = 0

    for rt in route_tables:
        # get route table name from tags
        rt_name = "unnamed"
        for tag in rt.get("Tags", []):
            if tag["Key"] == "Name":
                rt_name = tag["Value"]

        vpc_id = rt["VpcId"]

        # check if default route points to TGW
        has_tgw_route = False
        for route in rt.get("Routes", []):
            if route.get("DestinationCidrBlock") == "0.0.0.0/0" and route.get("TransitGatewayId"):
                has_tgw_route = True
                break

        if has_tgw_route:
            print(f"  PASS  {rt_name} ({rt['RouteTableId']}) in {vpc_id}")
            passed += 1
        else:
            print(f"  FAIL  {rt_name} ({rt['RouteTableId']}) in {vpc_id}")
            failed += 1

    print("=" * 60)
    print(f"Results: {passed} passed, {failed} failed")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--account-id", required=True, help="AWS account ID")
    parser.add_argument("--region", default="eu-west-1", help="AWS region")
    args = parser.parse_args()

    validate(account_id=args.account_id, region=args.region)
