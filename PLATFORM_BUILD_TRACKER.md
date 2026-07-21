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
- [x] Static route 0.0.0.0/0 in fullmesh → inspection VPC
- [x] Static route 0.0.0.0/0 in shared → inspection VPC
- [x] Shared VPC created and associated to shared RT
- [ ] Validate: instance in spoke A CANNOT ping instance in spoke B directly

### Inspection VPC — AWS Network Firewall
- [x] Deploy NFW in inspection VPC (2 AZs, endpoint per AZ)
- [x] Enable appliance mode on inspection VPC TGW attachment
- [x] Create firewall policy (stateless + stateful rule groups)
- [x] Stateful rules: domain allow-list (*.amazonaws.com, github.com, pypi.org)
- [x] Stateful rules: custom Suricata rules (block SSH/SMTP/RDP outbound, alert .ru domains)
- [x] Stateless rules: forward HTTPS/DNS/HTTP to stateful, drop rest
- [x] Configure TGW routing: spoke 0.0.0.0/0 → inspection attachment
- [x] Configure inspection VPC routing: TGW subnet → FW endpoint → NAT GW → IGW
- [x] Configure return path: public subnet 10.0.0.0/8 → FW endpoint
- [x] Firewall logging to CloudWatch (alerts + flows)
- [x] NAT Gateway + EIP for centralized egress
- [ ] Validate: traffic from spoke traverses NFW (check firewall flow logs)
- [ ] Validate: blocked domain returns RST/timeout
- [ ] Validate: source IP from spoke is the NAT GW EIP

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

### AWS Validators (boto3)
- [x] VPC routes collector (assume role, fetch route tables)
- [x] VPC routes validator (check 0.0.0.0/0 → TGW exists)
- [ ] TGW routes collector (fetch TGW route tables from networking account)
- [ ] TGW routes validator (compare state file vs live API)
- [ ] TGW associations validator (confirm correct attachments per RT)
- [ ] Firewall policy validator (rule groups attached, capacity OK)
- [ ] VPN tunnel validator (both tunnels UP, correct prefixes)
- [ ] Unit tests with mocked AWS responses (pytest)

### Drift Detection (automated)
- [ ] Lambda function runs validation on schedule (EventBridge, every 6 hours)
- [ ] If drift detected: publish to SNS topic
- [ ] Store drift history in DynamoDB (trend over time)
- [ ] Dashboard widget showing drift count

---

## Phase 7 — Python Network Automation (Netmiko + Jinja2)

### Configurator Framework (GNS3 lab)
- [x] Inventory file (all 20 routers with ports and variables)
- [x] Jinja2 template: MPLS base config (CEF, loopback, OSPF, MPLS on all interfaces)
- [x] Jinja2 template: PE VRF config (VRF, RD, RT, MP-BGP vpnv4, PE-CE peering)
- [x] push_config.py (render template + push via telnet)
- [x] --dry-run mode (print without pushing)
- [ ] Jinja2 template: CE router config (eBGP to PE, advertise customer routes)
- [ ] Jinja2 template: P router base (OSPF + MPLS only, no BGP)
- [ ] Jinja2 template: interface IP addressing (per-link IPs from inventory)
- [ ] Jinja2 template: OSPF cost tuning (set cost per interface)
- [ ] Jinja2 template: BGP route-policy (local-pref, AS-PATH prepend, communities)

### Collectors (read state from routers)
- [ ] show_commands.py — connect to router, run show commands, return output
- [ ] bgp_collector.py — collect BGP neighbor state from all PEs
- [ ] route_collector.py — collect routing table from all routers
- [ ] mpls_collector.py — collect MPLS forwarding table, LDP neighbors

### Validators (compare expected vs actual)
- [ ] bgp_validator.py — check all BGP sessions are Established
- [ ] ospf_validator.py — check all OSPF neighbors are Full
- [ ] mpls_validator.py — check LDP neighbors match expected list
- [ ] route_validator.py — check expected prefixes exist in routing table

### Reports
- [ ] health_report.py — run all validators, print summary (PASS/FAIL per router)
- [ ] Output to JSON for further processing
- [ ] Output to HTML for dashboard/sharing

---

## Phase 8 — Hybrid Connectivity (AWS VPN + On-Prem)

### Site-to-Site VPN
- [ ] Create VPN module (`terraform/modules/vpn/`)
- [ ] VPN connection attached to TGW (BGP, 2 tunnels)
- [ ] Download config and apply to GNS3/EVE-NG router
- [ ] Establish eBGP session (AS 65000 ↔ AS 64512)
- [ ] Advertise on-prem prefixes to AWS
- [ ] Receive AWS VPC prefixes on on-prem router
- [ ] Validate: on-prem router has routes to all spoke VPC CIDRs
- [ ] Validate: instance in spoke VPC can ping on-prem loopback
- [ ] Configure BGP AS-PATH prepend on backup tunnel
- [ ] Test failover: shut primary tunnel, traffic shifts to backup
- [ ] Python: automate VPN router config via Netmiko template

---

## Phase 9 — Multi-Region

- [ ] Deploy TGW in second region (eu-west-2)
- [ ] Create TGW peering between eu-west-1 and eu-west-2
- [ ] Add static routes on both sides (peering = no propagation)
- [ ] Validate: cross-region connectivity works
- [ ] Validate: latency is within expected range
- [ ] Consider Cloud WAN migration (replace TGW peering with segments)

---

## Phase 10 — Production Hardening

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

- Phase 2 complete — inspection VPC, Network Firewall, centralized egress all deployed
- Ansible removed — replaced with Python/Netmiko/Jinja2 (can't use SSH with GNS3 local)
- desired-state/ folder removed — using Terraform state as source of truth for drift detection
- Python automation uses telnet to GNS3 routers on localhost (Netmiko cisco_ios_telnet)
- Next priorities: validate firewall works end-to-end, then build more templates for MPLS lab
- VPN to on-prem is Phase 8 — needs GNS3 or EVE-NG router with IPsec+BGP
- Multi-region is last — get single-region production-solid first
- Each completed phase should result in a LinkedIn post or blog
