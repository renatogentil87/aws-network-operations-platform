output "pipeline_name" {
  value = aws_codepipeline.this.name
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.id
}

output "plan_notifications_topic_arn" {
  value = aws_sns_topic.plan_notifications.arn
}
