# Platform Build Tracker

**Project:** AWS Network Operations Platform
**Goal:** Production-grade hybrid network with IaC, validation, and observability
**Start:** Jun 2026 | **Target:** Feature-complete by Dec 2026

---

## Phase 1 — Network Foundation

- [x] Terraform state backend (S3 + DynamoDB)
- [x] CI/CD pipeline (CodePipeline + CodeBuild)
- [x] Transit Gateway with route tables (shared, fullmesh, firewall, spoke)
- [x] VPC module (IPAM allocation, TGW/public/private subnets, IGW, route tables)
- [x] TGW VPC attachments (auto-accept via RAM share)
- [x] Spoke VPCs deployed (dev1, prod, inspection, eveng)
- [x] Route table associations (private → TGW, public → IGW)
- [x] EC2 module (IAM role, SSM, security group, instance)
- [x] Cross-account provider configuration (assume role per account)
- [x] VPC Block Public Access exclusion for lab VPC

---

## Phase 2 — Segmentation & Inspection

### TGW Route Table Design
- [x] Define segmentation policy (which VPCs can talk to which)
- [x] Spoke RT: propagate only shared services + inspection VPC
- [x] Shared RT: propagate all VPCs + on-prem (future)
- [x] Inspection RT: propagate all spokes (return path)
- [x] Fullmesh RT: propagate everything (unrestricted VPCs)
- [ ] Validate: instance in spoke A CANNOT ping instance in spoke B directly

### Inspection VPC — AWS Network Firewall
- [ ] Create Network Firewall module (`terraform/modules/network-firewall/`)
- [ ] Deploy NFW in inspection VPC (2 AZs, endpoint per AZ)
- [ ] Enable appliance mode on inspection VPC TGW attachment
- [ ] Create firewall policy (stateless + stateful rule groups)
- [ ] Stateful rules: allow DNS, HTTPS; deny everything else by default
- [ ] Stateful rules: domain allow-list (e.g., *.amazonaws.com, specific SaaS)
- [ ] Configure TGW routing: spoke `0.0.0.0/0` → inspection attachment
- [ ] Configure inspection VPC routing: NFW endpoint → NAT GW → IGW
- [ ] Configure return path: inspection RT has routes back to each spoke CIDR
- [ ] Validate: traffic from spoke traverses NFW (check firewall flow logs)
- [ ] Validate: blocked domain returns RST/timeout

### Egress VPC (Centralized Internet)
- [ ] Create egress VPC (or combine with inspection VPC — decide)
- [ ] NAT Gateway in public subnet (2 AZs for HA)
- [ ] Elastic IP attached (stable IP for third-party whitelisting)
- [ ] IGW attached
- [ ] TGW routing: post-inspection traffic → egress VPC → internet
- [ ] Validate: instance in spoke VPC can reach the internet via centralized path
- [ ] Validate: source IP is the EIP (not the instance IP)

---

## Phase 3 — Shared Services

### Route 53 Resolver (Hybrid DNS)
- [ ] Create shared services VPC (or use existing)
- [ ] Deploy Route 53 Resolver inbound endpoints (on-prem → AWS DNS)
- [ ] Deploy Route 53 Resolver outbound endpoints (AWS → on-prem DNS)
- [ ] Create forwarding rules (e.g., corp.internal → on-prem DNS servers)
- [ ] Share resolver rules via RAM to all spoke accounts
- [ ] Validate: instance in spoke VPC resolves on-prem hostname
- [ ] Validate: on-prem device resolves AWS private hosted zone

### VPC Endpoints (cost + security)
- [ ] Gateway endpoints: S3, DynamoDB (free, every VPC should have these)
- [ ] Interface endpoints in shared services VPC: SSM, STS, CloudWatch Logs
- [ ] Share via TGW (spoke traffic → TGW → shared services VPC → endpoint)
- [ ] Validate: SSM Session Manager works without internet path

---

## Phase 4 — Hybrid Connectivity

### Site-to-Site VPN
- [ ] Create VPN module (`terraform/modules/vpn/`)
- [ ] VPN connection attached to TGW (BGP, 2 tunnels)
- [ ] Download config and apply to EVE-NG router (vIOS)
- [ ] Establish eBGP session (AS 65000 ↔ AS 64512)
- [ ] Advertise on-prem prefixes to AWS (e.g., 10.0.0.0/24, 10.0.1.0/24)
- [ ] Receive AWS VPC prefixes on on-prem router
- [ ] Validate: on-prem router has routes to all spoke VPC CIDRs
- [ ] Validate: instance in spoke VPC can ping on-prem loopback
- [ ] Configure BGP AS-PATH prepend on backup tunnel
- [ ] Test failover: shut primary tunnel, traffic shifts to backup

### VPN Monitoring
- [ ] CloudWatch alarms for tunnel status (TunnelState metric)
- [ ] EventBridge rule: tunnel DOWN → SNS notification
- [ ] Lambda function to log tunnel state changes

---

## Phase 5 — Observability

### VPC Flow Logs
- [ ] Enable flow logs on all VPCs (CloudWatch Logs, custom fields)
- [ ] Custom format: version, account, interface, srcaddr, dstaddr, srcport, dstport, protocol, packets, bytes, start, end, action, log-status, vpc-id, subnet-id, az-id, flow-direction, traffic-path
- [ ] S3 export for long-term retention (Athena queryable)
- [ ] Validate: can see traffic flows between spokes through firewall

### CloudWatch Dashboards
- [ ] Dashboard: TGW bytes in/out per attachment
- [ ] Dashboard: VPN tunnel status (UP/DOWN)
- [ ] Dashboard: Network Firewall blocked requests by rule
- [ ] Dashboard: NAT Gateway bytes processed + error counts
- [ ] Dashboard: Flow log rejected traffic (potential security events)

### Alarms
- [ ] VPN tunnel DOWN
- [ ] NFW alert log count > threshold
- [ ] NAT GW ErrorPortAllocation
- [ ] TGW packet drop count > 0
- [ ] Unexpected blackhole route detected (custom metric via Lambda)

---

## Phase 6 — Python Validation Framework

### CLI Structure
- [ ] `netops validate routes` — TGW route tables vs desired state
- [ ] `netops validate isolation` — confirm spoke-to-spoke blocked
- [ ] `netops validate firewall-path` — trace traffic through NFW
- [ ] `netops validate vpn` — both tunnels UP, correct prefixes
- [ ] `netops validate dns` — resolver endpoints healthy, forwarding works
- [ ] `netops collect state` — snapshot all network state to JSON
- [ ] `netops report health` — full health check, HTML output

### Desired-State Validation
- [ ] Define `desired-state/desired-routes-tgw.yaml` (expected routes per RT)
- [ ] Define `desired-state/desired-bgp-peers.yaml` (expected BGP sessions)
- [ ] Define `desired-state/desired-vpn-tunnels.yaml` (expected tunnel states)
- [ ] Write validator: read YAML → fetch actual state → compare → report
- [ ] Unit tests with mocked AWS responses (pytest)

### Drift Detection (automated)
- [ ] Lambda function runs validation on schedule (EventBridge, every 6 hours)
- [ ] If drift detected: publish to SNS topic
- [ ] Store drift history in DynamoDB (trend over time)
- [ ] Dashboard widget showing drift count

---

## Phase 7 — Automation & Remediation

### Ansible On-Prem Automation
- [ ] Playbook: configure BGP peer (idempotent)
- [ ] Playbook: route audit (compare actual vs expected)
- [ ] Playbook: emergency shutdown (disable BGP peer, withdraw routes)
- [ ] Role: base_router (NTP, logging, SNMP, AAA)
- [ ] Role: vpn_to_aws (tunnel config, crypto, BGP)
- [ ] Inventory: EVE-NG lab devices (working connectivity)

### Auto-Remediation
- [ ] VPN tunnel down → auto-check BGP state → restart if stale
- [ ] Blackhole route detected → alert + log (don't auto-fix — too risky)
- [ ] Drift detected → create ticket automatically (SIM/Asana integration)
- [ ] NFW blocking legitimate traffic → alert with rule ID for review

---

## Phase 8 — Multi-Region

- [ ] Deploy TGW in second region (eu-west-2)
- [ ] Create TGW peering between eu-west-1 and eu-west-2
- [ ] Add static routes on both sides (peering = no propagation)
- [ ] Validate: cross-region connectivity works
- [ ] Validate: latency is within expected range
- [ ] Consider Cloud WAN migration (replace TGW peering with segments)
- [ ] If Cloud WAN: implement routing policies (summarization, local-pref)

---

## Phase 9 — Production Hardening

- [ ] Terraform: add `prevent_destroy` lifecycle on critical resources
- [ ] Terraform: tag compliance (all resources tagged with owner, environment, project)
- [ ] Security: review all security group rules (least privilege)
- [ ] Security: enable GuardDuty in all accounts
- [ ] Security: enable Config rules for network compliance
- [ ] Cost: review NAT GW / data transfer costs
- [ ] Cost: consider VPC endpoints to reduce NAT traffic
- [ ] Documentation: architecture diagram (draw.io, publishable)
- [ ] Documentation: operational runbook for each failure scenario
- [ ] Testing: chaos test — kill a NAT GW, verify failover
- [ ] Testing: chaos test — blackhole a route, verify detection

---

## Notes

- Inspection VPC is the highest-value next step — proves segmentation works
- VPN to EVE-NG is second priority — enables real hybrid validation
- Python validators come after infra exists (need something to validate against)
- Multi-region is last — get single-region production-solid first
- Each completed phase should result in a LinkedIn post or blog
