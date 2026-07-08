# Runbook: BGP Flap Response

## Trigger
- CloudWatch alarm: VPN tunnel state change
- EventBridge: TGW route withdrawal detected
- Syslog: BGP neighbor state change received in CloudWatch Logs

## Severity Assessment

| Condition | Severity | Action |
|-----------|----------|--------|
| Single flap, recovers within 30s | LOW | Log only |
| >3 flaps in 5 minutes | MEDIUM | Alert + investigate |
| Session DOWN > 2 minutes | HIGH | Alert + validate failover path |
| Both tunnels DOWN | CRITICAL | Page on-call + auto-remediate |

## Investigation Steps

1. **Check AWS side:**
   ```bash
   netops validate bgp --region eu-west-1
   netops validate vpn --region eu-west-1
   ```

2. **Check on-prem side:**
   ```bash
   netops collect device --host router-edge1
   # Or via Ansible:
   ansible-playbook playbooks/route_audit.yml --limit router-edge1
   ```

3. **Correlate both sides:**
   ```bash
   netops collect hybrid --region eu-west-1 --device router-edge1
   ```

## Remediation

### If: Flap storm (>3 flaps in 5 min) — auto-shutdown
```bash
# Python remediator calls Ansible:
ansible-playbook playbooks/emergency_shutdown.yml \
  -i inventory/gns3_lab.yml \
  -e "target_host=router-edge1 neighbor_ip=169.254.100.2"
```

### If: AWS-side issue — check TGW routes
```bash
netops validate routes --region eu-west-1
# Look for blackhole routes or missing propagations
```

### If: On-prem issue — check OSPF convergence
```bash
# Via netmiko or Ansible
show ip ospf neighbor
show ip route ospf
# Verify OSPF adjacencies are up and routes are present
```

## Post-Incident

1. Verify BGP is re-established: `netops validate bgp`
2. Verify routes are correct on both sides: `netops validate routes`
3. Document in remediation log: `outputs/remediation_log.txt`
4. If auto-shutdown was triggered, manually re-enable after root cause is identified:
   ```
   router bgp 65000
    no neighbor 169.254.100.2 shutdown
   ```
