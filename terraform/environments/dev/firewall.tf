locals {
  availability_zones = ["eu-west-1a", "eu-west-1b"]

  # Extract firewall endpoint IDs per AZ from the firewall resource
  firewall_endpoints = {
    for state in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    state.availability_zone => state.attachment[0].endpoint_id
  }
}

### FIREWALL SUBNETS

resource "aws_subnet" "fw_subnet" {
  provider          = aws.network
  count             = length(local.availability_zones)
  vpc_id            = module.inspection_vpc.vpc_id
  cidr_block        = cidrsubnet(module.inspection_vpc.vpc_cidr_block, 6, count.index + 6)
  availability_zone = local.availability_zones[count.index]
  tags = {
    Name = "inspection-vpc-fw-subnet-${local.availability_zones[count.index]}"
  }
}

### INSPECTION VPC INTERNAL ROUTING

# --- TGW Subnet Route Tables (one per AZ → firewall endpoint) ---

resource "aws_route_table" "tgw_subnet_rt" {
  provider = aws.network
  count    = length(local.availability_zones)
  vpc_id   = module.inspection_vpc.vpc_id

  tags = {
    Name = "inspection-vpc-tgw-subnet-rt-${local.availability_zones[count.index]}"
  }
}

resource "aws_route_table_association" "tgw_subnet_association" {
  provider       = aws.network
  count          = length(local.availability_zones)
  subnet_id      = module.inspection_vpc.tgw_subnet_ids[count.index]
  route_table_id = aws_route_table.tgw_subnet_rt[count.index].id
}

resource "aws_route" "tgw_subnet_to_fw_endpoint" {
  provider               = aws.network
  count                  = length(local.availability_zones)
  route_table_id         = aws_route_table.tgw_subnet_rt[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = local.firewall_endpoints[local.availability_zones[count.index]]
}

# --- Firewall Subnet Route Table (post-inspection → NAT GW) ---

resource "aws_route_table" "fw_subnet_rt" {
  provider = aws.network
  vpc_id   = module.inspection_vpc.vpc_id

  tags = {
    Name = "inspection-vpc-fw-subnet-rt"
  }
}

resource "aws_route_table_association" "fw_subnet_association" {
  provider       = aws.network
  count          = length(local.availability_zones)
  subnet_id      = aws_subnet.fw_subnet[count.index].id
  route_table_id = aws_route_table.fw_subnet_rt.id
}

resource "aws_route" "fw_subnet_to_natgw" {
  provider               = aws.network
  route_table_id         = aws_route_table.fw_subnet_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw.id
}

# --- Public Subnet Return Routes (internet return → firewall endpoint per AZ) ---
# Return traffic from internet needs to go back through the firewall before reaching TGW

resource "aws_route" "public_return_to_fw_az_a" {
  provider               = aws.network
  route_table_id         = module.inspection_vpc.public_rt
  destination_cidr_block = "10.0.0.0/8"
  vpc_endpoint_id        = local.firewall_endpoints["eu-west-1a"]
}

### NETWORK FIREWALL

resource "aws_networkfirewall_firewall" "this" {
  provider                 = aws.network
  name                     = "central-egress-firewall"
  vpc_id                   = module.inspection_vpc.vpc_id
  firewall_policy_arn      = aws_networkfirewall_firewall_policy.this.arn
  delete_protection        = true
  subnet_change_protection = true
  description              = "Network Firewall for centralized egress"

  subnet_mapping {
    subnet_id = aws_subnet.fw_subnet[0].id
  }
  subnet_mapping {
    subnet_id = aws_subnet.fw_subnet[1].id
  }

  tags = {
    Name = "central-egress-firewall"
  }
}

### FIREWALL POLICY

resource "aws_networkfirewall_firewall_policy" "this" {
  provider = aws.network
  name     = "inspection-firewall-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateless_rule_group_reference {
      priority     = 1
      resource_arn = aws_networkfirewall_rule_group.stateless.arn
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateful_domain.arn
    }

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.stateful_suricata.arn
    }
  }

  tags = {
    Name = "inspection-firewall-policy"
  }
}

### STATELESS RULE GROUP

resource "aws_networkfirewall_rule_group" "stateless" {
  provider = aws.network
  name     = "inspection-stateless-rules"
  type     = "STATELESS"
  capacity = 100

  rule_group {
    rules_source {
      stateless_rules_and_custom_actions {

        # Forward HTTPS (TCP 443) to stateful engine
        stateless_rule {
          priority = 1
          rule_definition {
            actions = ["aws:forward_to_sfe"]
            match_attributes {
              source {
                address_definition = "0.0.0.0/0"
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
              destination_port {
                from_port = 443
                to_port   = 443
              }
              protocols = [6]
            }
          }
        }

        # Forward DNS (UDP 53) to stateful engine
        stateless_rule {
          priority = 2
          rule_definition {
            actions = ["aws:forward_to_sfe"]
            match_attributes {
              source {
                address_definition = "0.0.0.0/0"
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
              destination_port {
                from_port = 53
                to_port   = 53
              }
              protocols = [17]
            }
          }
        }

        # Forward HTTP (TCP 80) to stateful engine
        stateless_rule {
          priority = 3
          rule_definition {
            actions = ["aws:forward_to_sfe"]
            match_attributes {
              source {
                address_definition = "0.0.0.0/0"
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
              destination_port {
                from_port = 80
                to_port   = 80
              }
              protocols = [6]
            }
          }
        }

        # Drop everything else
        stateless_rule {
          priority = 100
          rule_definition {
            actions = ["aws:drop"]
            match_attributes {
              source {
                address_definition = "0.0.0.0/0"
              }
              destination {
                address_definition = "0.0.0.0/0"
              }
              protocols = [0]
            }
          }
        }

      }
    }
  }

  tags = {
    Name = "inspection-stateless-rules"
  }
}

### STATEFUL RULE GROUP — DOMAIN ALLOW LIST

resource "aws_networkfirewall_rule_group" "stateful_domain" {
  provider = aws.network
  name     = "inspection-domain-allowlist"
  type     = "STATEFUL"
  capacity = 100

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = ["10.0.0.0/8"]
        }
      }
    }

    rules_source {
      rules_source_list {
        generated_rules_type = "ALLOWLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets = [
          ".amazonaws.com",
          ".aws.amazon.com",
          ".ubuntu.com",
          ".github.com",
          ".pypi.org",
        ]
      }
    }
  }

  tags = {
    Name = "inspection-domain-allowlist"
  }
}

### STATEFUL RULE GROUP — CUSTOM SURICATA RULES

resource "aws_networkfirewall_rule_group" "stateful_suricata" {
  provider = aws.network
  name     = "inspection-suricata-rules"
  type     = "STATEFUL"
  capacity = 100

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = ["10.0.0.0/8"]
        }
      }
      ip_sets {
        key = "EXTERNAL_NET"
        ip_set {
          definition = ["0.0.0.0/0"]
        }
      }
    }

    rules_source {
      rules_string = file("${path.module}/rules/suricata.rules")
    }
  }

  tags = {
    Name = "inspection-suricata-rules"
  }
}

### LOGGING CONFIGURATION

resource "aws_cloudwatch_log_group" "firewall_alerts" {
  provider          = aws.network
  name              = "/aws/network-firewall/alerts"
  retention_in_days = 30

  tags = {
    Name = "network-firewall-alerts"
  }
}

resource "aws_cloudwatch_log_group" "firewall_flows" {
  provider          = aws.network
  name              = "/aws/network-firewall/flows"
  retention_in_days = 30

  tags = {
    Name = "network-firewall-flows"
  }
}

resource "aws_networkfirewall_logging_configuration" "this" {
  provider    = aws.network
  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_alerts.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }

    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_flows.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
  }
}
