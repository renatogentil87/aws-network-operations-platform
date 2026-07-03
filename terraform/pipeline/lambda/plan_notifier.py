import boto3
import json
import os

s3 = boto3.client("s3")
sns = boto3.client("sns")


def handler(event, context):
    """
    Triggered by EventBridge when the Plan stage of the pipeline succeeds.
    Reads the terraform plan output from S3 and sends it via SNS email.
    """
    pipeline_name = event["detail"]["pipeline"]
    execution_id = event["detail"]["execution-id"]
    region = os.environ["AWS_REGION"]
    account_id = context.invoked_function_arn.split(":")[4]

    # Read plan output from S3
    bucket = os.environ["PLAN_BUCKET"]
    try:
        response = s3.get_object(Bucket=bucket, Key="plan-output/latest.txt")
        plan_output = response["Body"].read().decode("utf-8")
    except Exception as e:
        plan_output = f"Failed to read plan output: {str(e)}"

    # Truncate if too long for SNS (256KB limit, but emails should be readable)
    max_length = 50000
    if len(plan_output) > max_length:
        plan_output = plan_output[:max_length] + "\n\n... [TRUNCATED — view full output in CodeBuild logs]"

    # Build approval console link
    approval_url = (
        f"https://{region}.console.aws.amazon.com/codesuite/codepipeline/pipelines/"
        f"{pipeline_name}/view?region={region}"
    )

    # Build email body
    subject = f"[NetOps] Terraform Plan Ready for Approval — {pipeline_name}"
    body = f"""Terraform Plan Output — Pipeline: {pipeline_name}
Execution ID: {execution_id}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
APPROVE / REJECT IN CONSOLE:
{approval_url}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

TERRAFORM PLAN:
────────────────────────────────────────────────────
{plan_output}
────────────────────────────────────────────────────

To approve: Click the link above → Review → Approve
To reject:  Click the link above → Review → Reject
"""

    # Send via SNS
    topic_arn = os.environ["SNS_TOPIC_ARN"]
    sns.publish(
        TopicArn=topic_arn,
        Subject=subject[:100],  # SNS subject max 100 chars
        Message=body,
    )

    return {"statusCode": 200, "body": "Notification sent"}
