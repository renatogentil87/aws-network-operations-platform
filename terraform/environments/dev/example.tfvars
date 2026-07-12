# Copy this file to terraform.tfvars and fill in your account IDs
# DO NOT commit terraform.tfvars to git — it contains sensitive account IDs
#
# In the CI/CD pipeline, these values are passed via TF_VAR_* environment
# variables configured in the CodeBuild projects (see terraform/pipeline/main.tf)

aws_region = "eu-west-1"

network_account_id         = ""  # Network/Hub account
perimeter_account_id       = ""  # Perimeter/Firewall account
shared_services_account_id = ""  # Shared Services account
spoke_account_id           = ""  # Spoke Dev1 account
spoke2_account_id          = ""  # Spoke Dev2 account
eveng_account_id          = "" # Even NG Account