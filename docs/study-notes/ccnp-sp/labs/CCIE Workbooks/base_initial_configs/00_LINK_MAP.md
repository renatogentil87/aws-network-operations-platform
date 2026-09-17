# SP-CORE Base Topology — Link Map & Addressing (day-0 initial configs)

Day-0 configs contain hostnames, Loopback0, and interface IP addressing ONLY.
No IGP/LDP/BGP — the workbooks build those. Interface names are illustrative
(GigabitEthernet0/N in assignment order); adjust to your GNS3/EVE-NG node type.

## Loopbacks

| Node | Loopback0 |
|------|-----------|
| PE1 | 10.0.0.1/32 |
| PE2 | 10.0.0.2/32 |
| PE3 | 10.0.0.3/32 |
| PE4 | 10.0.0.4/32 |
| PE5 | 10.0.0.5/32 |
| PE6 | 10.0.0.6/32 |
| P1 | 10.0.0.11/32 |
| P2 | 10.0.0.12/32 |
| P3 | 10.0.0.13/32 |
| P4 | 10.0.0.14/32 |
| P5 | 10.0.0.15/32 |
| P6 | 10.0.0.16/32 |
| RR1 | 10.0.0.101/32 |
| RR2 | 10.0.0.102/32 |
| CE1 | 192.168.1.1/32 |
| CE2 | 192.168.2.1/32 |
| CE3 | 192.168.3.1/32 |
| CE4 | 192.168.4.1/32 |
| CE5 | 192.168.5.1/32 |
| CE6 | 192.168.6.1/32 |

## Core / Infrastructure links (/30)

| Subnet | A (.1) | B (.2) |
|--------|--------|--------|
| 10.1.1.0/30 | P1 | P3 |
| 10.1.2.0/30 | P3 | P5 |
| 10.1.3.0/30 | P2 | P4 |
| 10.1.4.0/30 | P4 | P6 |
| 10.1.5.0/30 | P1 | P2 |
| 10.1.6.0/30 | P3 | P4 |
| 10.1.7.0/30 | P5 | P6 |
| 10.1.8.0/30 | P3 | RR1 |
| 10.1.9.0/30 | P4 | RR2 |
| 10.1.10.0/30 | RR1 | RR2 |
| 10.1.11.0/30 | PE1 | P1 |
| 10.1.12.0/30 | PE2 | P1 |
| 10.1.13.0/30 | PE3 | P5 |
| 10.1.14.0/30 | PE4 | P6 |
| 10.1.15.0/30 | PE5 | P2 |
| 10.1.16.0/30 | PE6 | P6 |

## PE-CE links (/30)

| Subnet | PE (.1) | CE (.2) | Customer |
|--------|---------|---------|----------|
| 10.2.1.0/30 | PE1 | CE1 | A/65001 |
| 10.2.2.0/30 | PE2 | CE2 | B/65002 |
| 10.2.3.0/30 | PE3 | CE3 | A/65001 |
| 10.2.4.0/30 | PE4 | CE4 | B/65002 |
| 10.2.5.0/30 | PE5 | CE5 | C/65003 |
| 10.2.6.0/30 | PE6 | CE6 | D/65004 |

## Per-node interface assignments

**PE1** (Lo0 10.0.0.1): GigabitEthernet0/0=10.1.11.1 (to P1), GigabitEthernet0/1=10.2.1.1 (to CE1 (customer edge))
**PE2** (Lo0 10.0.0.2): GigabitEthernet0/0=10.1.12.1 (to P1), GigabitEthernet0/1=10.2.2.1 (to CE2 (customer edge))
**PE3** (Lo0 10.0.0.3): GigabitEthernet0/0=10.1.13.1 (to P5), GigabitEthernet0/1=10.2.3.1 (to CE3 (customer edge))
**PE4** (Lo0 10.0.0.4): GigabitEthernet0/0=10.1.14.1 (to P6), GigabitEthernet0/1=10.2.4.1 (to CE4 (customer edge))
**PE5** (Lo0 10.0.0.5): GigabitEthernet0/0=10.1.15.1 (to P2), GigabitEthernet0/1=10.2.5.1 (to CE5 (customer edge))
**PE6** (Lo0 10.0.0.6): GigabitEthernet0/0=10.1.16.1 (to P6), GigabitEthernet0/1=10.2.6.1 (to CE6 (customer edge))
**P1** (Lo0 10.0.0.11): GigabitEthernet0/0=10.1.1.1 (to P3), GigabitEthernet0/1=10.1.5.1 (to P2), GigabitEthernet0/2=10.1.11.2 (to PE1), GigabitEthernet0/3=10.1.12.2 (to PE2)
**P2** (Lo0 10.0.0.12): GigabitEthernet0/0=10.1.3.1 (to P4), GigabitEthernet0/1=10.1.5.2 (to P1), GigabitEthernet0/2=10.1.15.2 (to PE5)
**P3** (Lo0 10.0.0.13): GigabitEthernet0/0=10.1.1.2 (to P1), GigabitEthernet0/1=10.1.2.1 (to P5), GigabitEthernet0/2=10.1.6.1 (to P4), GigabitEthernet0/3=10.1.8.1 (to RR1)
**P4** (Lo0 10.0.0.14): GigabitEthernet0/0=10.1.3.2 (to P2), GigabitEthernet0/1=10.1.4.1 (to P6), GigabitEthernet0/2=10.1.6.2 (to P3), GigabitEthernet0/3=10.1.9.1 (to RR2)
**P5** (Lo0 10.0.0.15): GigabitEthernet0/0=10.1.2.2 (to P3), GigabitEthernet0/1=10.1.7.1 (to P6), GigabitEthernet0/2=10.1.13.2 (to PE3)
**P6** (Lo0 10.0.0.16): GigabitEthernet0/0=10.1.4.2 (to P4), GigabitEthernet0/1=10.1.7.2 (to P5), GigabitEthernet0/2=10.1.14.2 (to PE4), GigabitEthernet0/3=10.1.16.2 (to PE6)
**RR1** (Lo0 10.0.0.101): GigabitEthernet0/0=10.1.8.2 (to P3), GigabitEthernet0/1=10.1.10.1 (to RR2)
**RR2** (Lo0 10.0.0.102): GigabitEthernet0/0=10.1.9.2 (to P4), GigabitEthernet0/1=10.1.10.2 (to RR1)
**CE1** (Lo0 192.168.1.1): GigabitEthernet0/0=10.2.1.2 (to PE1 (provider edge))
**CE2** (Lo0 192.168.2.1): GigabitEthernet0/0=10.2.2.2 (to PE2 (provider edge))
**CE3** (Lo0 192.168.3.1): GigabitEthernet0/0=10.2.3.2 (to PE3 (provider edge))
**CE4** (Lo0 192.168.4.1): GigabitEthernet0/0=10.2.4.2 (to PE4 (provider edge))
**CE5** (Lo0 192.168.5.1): GigabitEthernet0/0=10.2.5.2 (to PE5 (provider edge))
**CE6** (Lo0 192.168.6.1): GigabitEthernet0/0=10.2.6.2 (to PE6 (provider edge))
