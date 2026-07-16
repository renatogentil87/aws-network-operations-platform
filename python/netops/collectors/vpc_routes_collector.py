"""
VPC Routes Collector — Assumes role into an account and returns all route tables.
"""

import boto3


def get_all_route_tables(account_id, region="eu-west-1"):
    """
    Assume role into an account and return all route tables.
    """

    role_arn = f"arn:aws:iam::{account_id}:role/NetOps-Collector"

    # Assume role into the target account
    sts = boto3.client("sts")
    creds = sts.assume_role(RoleArn=role_arn, RoleSessionName="netops-collector")

    ec2 = boto3.client(
        "ec2",
        region_name=region,
        aws_access_key_id=creds["Credentials"]["AccessKeyId"],
        aws_secret_access_key=creds["Credentials"]["SecretAccessKey"],
        aws_session_token=creds["Credentials"]["SessionToken"],
    )

    # Get all route tables in the account
    route_tables = ec2.describe_route_tables()["RouteTables"]

    return route_tables
