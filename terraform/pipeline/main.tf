# Artifact bucket
resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "netops-pipeline-artifacts-"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration { status = "Enabled" }
}

# SNS topic for manual approval notifications
resource "aws_sns_topic" "approval" {
  name = "netops-pipeline-approval"
}

# CodeBuild — Terraform Plan
resource "aws_codebuild_project" "plan" {
  name         = "netops-terraform-plan"
  service_role = aws_iam_role.codebuild.arn

  artifacts { type = "CODEPIPELINE" }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "TF_VERSION"
      value = var.terraform_version
    }
    environment_variable {
      name  = "TF_VAR_network_account_id"
      value = var.network_account_id
    }
    environment_variable {
      name  = "TF_VAR_perimeter_account_id"
      value = var.perimeter_account_id
    }
    environment_variable {
      name  = "TF_VAR_shared_services_account_id"
      value = var.shared_services_account_id
    }
    environment_variable {
      name  = "TF_VAR_spoke_account_id"
      value = var.spoke_account_id
    }
    environment_variable {
      name  = "TF_VAR_spoke2_account_id"
      value = var.spoke2_account_id
    }
    environment_variable {
      name  = "PLAN_BUCKET"
      value = aws_s3_bucket.artifacts.id
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        install:
          commands:
            - curl -s -o terraform.zip "https://releases.hashicorp.com/terraform/$${TF_VERSION}/terraform_$${TF_VERSION}_linux_amd64.zip"
            - unzip -q terraform.zip -d /usr/local/bin/
            - terraform --version
        build:
          commands:
            - set -o pipefail
            - cd terraform/environments/dev
            - terraform init -input=false
            - terraform plan -input=false -out=tfplan 2>&1 | tee plan_output.txt
            - terraform show -no-color tfplan > plan_readable.txt
            - aws s3 cp plan_readable.txt s3://$${PLAN_BUCKET}/plan-output/latest.txt
      artifacts:
        files:
          - terraform/environments/dev/tfplan
          - terraform/environments/dev/.terraform.lock.hcl
        base-directory: "."
    EOF
  }
}

# CodeBuild — Terraform Apply
resource "aws_codebuild_project" "apply" {
  name         = "netops-terraform-apply"
  service_role = aws_iam_role.codebuild.arn

  artifacts { type = "CODEPIPELINE" }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "TF_VERSION"
      value = var.terraform_version
    }
    environment_variable {
      name  = "TF_VAR_network_account_id"
      value = var.network_account_id
    }
    environment_variable {
      name  = "TF_VAR_perimeter_account_id"
      value = var.perimeter_account_id
    }
    environment_variable {
      name  = "TF_VAR_shared_services_account_id"
      value = var.shared_services_account_id
    }
    environment_variable {
      name  = "TF_VAR_spoke_account_id"
      value = var.spoke_account_id
    }
    environment_variable {
      name  = "TF_VAR_spoke2_account_id"
      value = var.spoke2_account_id
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-EOF
      version: 0.2
      phases:
        install:
          commands:
            - curl -s -o terraform.zip "https://releases.hashicorp.com/terraform/$${TF_VERSION}/terraform_$${TF_VERSION}_linux_amd64.zip"
            - unzip -q terraform.zip -d /usr/local/bin/
            - terraform --version
        build:
          commands:
            - cd terraform/environments/dev
            - terraform init -input=false
            - terraform apply -input=false -auto-approve
    EOF
  }
}

# CodePipeline
resource "aws_codepipeline" "this" {
  name     = "netops-infrastructure"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.id
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "GitHub"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source"]

      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = var.github_repo
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "Plan"

    action {
      name            = "TerraformPlan"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source"]
      output_artifacts = ["plan_output"]

      configuration = {
        ProjectName = aws_codebuild_project.plan.name
      }
    }
  }

  stage {
    name = "Apply"

    action {
      name             = "TerraformApply"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source"]

      configuration = {
        ProjectName = aws_codebuild_project.apply.name
      }
    }
  }
}
