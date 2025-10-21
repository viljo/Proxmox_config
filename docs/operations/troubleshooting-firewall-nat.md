# Troubleshooting: Firewall NAT and SNAT Issues

**Date Created**: 2025-10-21
**Last Updated**: 2025-10-21
**Severity**: Critical - Blocks all inbound WAN traffic

## Problem Summary

External traffic from the internet cannot reach services in the DMZ, even though:
- Outbound connectivity from DMZ works fine
- Firewall has correct DHCP lease on WAN interface
- DNS is configured correctly
- NAT DNAT rules appear correct

### Symptoms

1. Ping from internet to WAN IP times out (if ICMP not allowed)
2. HTTP/HTTPS requests to WAN IP timeout
3. `tcpdump` on WAN interface shows 0 inbound packets OR packets arrive but connections fail
4. Internal services can reach internet (outbound works)

## Root Cause Analysis

### The Issue: Missing SNAT for WAN→DMZ Traffic

When traffic arrives from the internet destined for DMZ services:

1. **Packet arrives** at firewall WAN interface (eth0) ✅
2. **DNAT rule fires** - destination changed from WAN IP to DMZ service IP (e.g., 172.16.10.2) ✅
3. **Packet forwarded** to DMZ via eth1 ✅
4. **DMZ service responds** (e.g., Traefik sends SYN-ACK) ✅
5. **❌ PROBLEM**: Reply packet routes via Proxmox host's default gateway (management network) instead of back through firewall

### Why This Happens

The Proxmox host has multiple network interfaces:
- Management network (vmbr0/enp0s31f6) with default route
- WAN bridge (vmbr2)
- DMZ bridge (vmbr3)

When DMZ services send replies to internet IPs, the Proxmox kernel's routing table uses the **default route** (management network), not the firewall. This causes:
- Reply packets exit the wrong interface
- Source IP doesn't match (asymmetric routing)
- Connection never establishes

### The Solution: SNAT/Masquerade WAN→DMZ Traffic

Add SNAT (masquerade) rule in firewall's POSTROUTING chain:

```nftables
iifname "eth0" oifname "eth1" masquerade
```

This changes the source IP of forwarded packets to the firewall's DMZ IP (172.16.10.1), ensuring replies route back through the firewall.

## Diagnostic Steps

### 1. Verify Basic Connectivity

```bash
# Ping WAN IP from internet
ping 158.174.33.69

# If ping fails, check if ICMP is allowed in firewall INPUT chain
ssh root@192.168.1.3 "pct exec 101 -- nft list table inet filter | grep -A 10 'chain input'"
```

Expected: Should see `icmp type { echo-request, echo-reply } accept`

### 2. Check if Packets Reach Firewall

```bash
# Capture on WAN bridge
ssh root@192.168.1.3 "timeout 10 tcpdump -i vmbr2 -n 'tcp port 80' -c 5"

# Then try accessing from internet
curl http://158.174.33.69/
```

Expected: Should see SYN packets arriving

### 3. Check NAT DNAT Rules

```bash
ssh root@192.168.1.3 "pct exec 101 -- nft list table ip nat"
```

Expected output:
```
chain prerouting {
    type nat hook prerouting priority dstnat; policy accept;
    iifname "eth0" tcp dport { 80, 443 } dnat to 172.16.10.2
}
```

### 4. **CRITICAL: Check for Asymmetric Routing**

```bash
# Capture packets to/from DMZ service
ssh root@192.168.1.3 "timeout 15 tcpdump -i any -n 'host 172.16.10.2 and tcp port 80'"

# Trigger request from internet
curl http://158.174.33.69/
```

**Look for**:
- SYN arriving on veth/vmbr3 (firewall→DMZ) ✅
- SYN-ACK leaving on **enp0s31f6 or vmbr0** (management network) ❌ **THIS IS THE PROBLEM**

Expected behavior:
- SYN-ACK should leave via veth/vmbr3 (DMZ→firewall)

### 5. Verify SNAT Rule Exists

```bash
ssh root@192.168.1.3 "pct exec 101 -- nft list table ip nat | grep -A 5 'chain postrouting'"
```

Expected output should include:
```
iifname "eth0" oifname "eth1" masquerade
```

## Resolution

### Quick Fix (Manual)

1. Add SNAT rule to running firewall:
```bash
ssh root@192.168.1.3 "pct exec 101 -- nft add rule ip nat postrouting iifname eth0 oifname eth1 masquerade"
```

2. Make persistent:
```bash
ssh root@192.168.1.3 "pct exec 101 -- cat > /etc/nftables.conf << 'EOF'
# ... (full config with SNAT rule)
EOF"

ssh root@192.168.1.3 "pct exec 101 -- systemctl restart nftables"
```

### Permanent Fix (Ansible)

The firewall role template at [roles/firewall/templates/nftables.conf.j2](../../roles/firewall/templates/nftables.conf.j2) has been updated to include:

1. **ICMP rules** in INPUT chain (allows ping diagnostics)
2. **SNAT rule** in POSTROUTING chain (fixes asymmetric routing)

Deploy with:
```bash
ansible-playbook -i inventory/hosts.yml playbooks/dmz-rebuild.yml --tags firewall
```

## Prevention

### Code Review Checklist

When reviewing firewall NAT configurations:

- [ ] DNAT rules in PREROUTING chain
- [ ] FORWARD chain allows bidirectional traffic (WAN→DMZ and DMZ→WAN)
- [ ] **SNAT/masquerade in POSTROUTING for WAN→DMZ traffic** ⚠️
- [ ] SNAT/masquerade in POSTROUTING for DMZ→WAN traffic
- [ ] ICMP allowed in INPUT chain (for diagnostics)

### Testing Procedure

After deploying firewall changes:

1. Test ping from external internet:
   ```bash
   ping <WAN_IP>
   ```

2. Test HTTP/HTTPS from external internet:
   ```bash
   curl -I http://<WAN_IP>/
   curl -I https://<DOMAIN>/
   ```

3. Verify packet flow with tcpdump:
   ```bash
   # Should see packets on BOTH interfaces
   ssh root@192.168.1.3 "timeout 10 tcpdump -i any -n 'host <SERVICE_IP> and tcp port 80'"
   ```

## Related Issues

- **Container ID Standardization**: Firewall container ID changed from 2200 → 101 (IP .1 + 100)
- **Loopia DDNS**: Updated to reference new container ID (101)
- **Network Architecture**: [docs/architecture/network-topology.md](../architecture/network-topology.md)

## References

- [nftables masquerade documentation](https://wiki.nftables.org/wiki-nftables/index.php/Performing_Network_Address_Translation_(NAT)#Masquerading)
- [Firewall role](../../roles/firewall/)
- [ADR-002: Container ID Standardization](../adr/002-container-id-standardization.md)

## Lessons Learned

1. **Always SNAT forwarded traffic** when firewall is not the default gateway
2. **Use tcpdump on "any" interface** to detect asymmetric routing
3. **Enable ICMP early** for easier diagnostics
4. **Test from external internet**, not just from Proxmox host
5. **Verify packet path end-to-end** with tcpdump, don't assume NAT works

---

**Issue First Encountered**: 2025-10-21
**Resolution Committed**: 2025-10-21
**Verified Working**: 2025-10-21 - https://demosite.viljo.se/ accessible
