# Exercise 01 — Establish BGP Peering

## Objective
Configure iBGP between Router-Core and Router-Edge1 using Ansible, then verify with Python.

## Steps

### Part A — Manual (understand what you're automating)
1. Console into Router-Core and Router-Edge1 in GNS3
2. Configure iBGP manually (AS 65000, loopback peering)
3. Verify with `show ip bgp summary` — confirm state is `Established`

### Part B — Ansible automation
1. Run: `ansible-playbook playbooks/bgp_config.yml -i inventory/gns3_lab.yml --limit router-core,router-edge1`
2. Verify the playbook achieves the same result as manual config

### Part C — Python validation
1. Write a script using netmiko that SSH's to both routers
2. Run `show ip bgp summary` and parse the output
3. Assert the BGP session is in `Established` state
4. Save the output to `outputs/bgp_state.json`

## Success Criteria
- [ ] BGP session Established between Core and Edge1
- [ ] Ansible playbook is idempotent (run twice, no changes second time)
- [ ] Python script validates and saves state as JSON
