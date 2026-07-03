# SNS topic for plan notifications
resource "aws_sns_topic" "plan_notifications" {
  name = "netops-plan-notifications"
}

data "archive_file" "plan_notifier" {
  type        = "zip"
  source_file = "${path.module}/lambda/plan_notifier.py"
  output_path = "${path.module}/lambda/plan_notifier.zip"
}

resource "aws_iam_role" "lambda_notifier" {
  name = "netops-plan-notifier-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_notifier" {
  name = "netops-plan-notifier-policy"
  role = aws_iam_role.lambda_notifier.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.artifacts.arn}/plan-output/*"
      },
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.plan_notifications.arn
      }
    ]
  })
}

resource "aws_lambda_function" "plan_notifier" {
  function_name    = "netops-plan-notifier"
  role             = aws_iam_role.lambda_notifier.arn
  handler          = "plan_notifier.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.plan_notifier.output_path
  source_code_hash = data.archive_file.plan_notifier.output_base64sha256

  environment {
    variables = {
      PLAN_BUCKET   = aws_s3_bucket.artifacts.id
      SNS_TOPIC_ARN = aws_sns_topic.plan_notifications.arn
    }
  }
}

# EventBridge rule — triggers when Plan stage succeeds
resource "aws_cloudwatch_event_rule" "plan_succeeded" {
  name = "netops-plan-stage-succeeded"

  event_pattern = jsonencode({
    source      = ["aws.codepipeline"]
    detail-type = ["CodePipeline Stage Execution State Change"]
    detail = {
      pipeline = [aws_codepipeline.this.name]
      stage    = ["Plan"]
      state    = ["SUCCEEDED"]
    }
  })
}

resource "aws_cloudwatch_event_target" "plan_notifier" {
  rule = aws_cloudwatch_event_rule.plan_succeeded.name
  arn  = aws_lambda_function.plan_notifier.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.plan_notifier.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.plan_succeeded.arn
}

# Email subscription — you'll receive a confirmation email
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.plan_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
