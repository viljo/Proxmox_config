# WireGuard VPN Firewall Configuration

This document describes how to configure the firewall to allow WireGuard VPN traffic and forward it to the WireGuard server container.

## Overview

**Architecture:**
- **WireGuard Server**: LXC Container 190 on management network (192.168.1.190)
- **Firewall**: LXC Container 101 on DMZ network (handles WAN traffic)
- **Protocol**: UDP port 51820
- **Direction**: Inbound from Internet → Firewall → WireGuard Server

## Network Topology

```
Internet (WAN)
     │
     │ UDP:51820
     ▼
┌─────────────────┐
│ Firewall CT 101 │
│ vmbr2 (WAN)     │  eth0: DHCP (public IP)
│ vmbr3 (DMZ)     │  eth1: 172.16.10.101/24
└────────┬────────┘
         │
    vmbr0 (Management Bridge)
         │
         ▼
┌─────────────────┐
│ WireGuard CT190 │
│ 192.168.1.190   │  eth0: 192.168.1.190/24
└─────────────────┘
         │
         ▼
   Management Network
   (192.168.0.0/16)
```

## Configuration Methods

### Method 1: Using nftables (Recommended)

The firewall container should use nftables for modern packet filtering and NAT.

#### 1. Check Current nftables Configuration

```bash
# SSH into firewall container
ssh root@172.16.10.101

# or from Proxmox host
pct exec 101 -- bash

# View current ruleset
nft list ruleset
```

#### 2. Add WireGuard Port Forward Rules

```bash
# Add PREROUTING rule to DNAT incoming WireGuard traffic
nft add rule inet nat prerouting iifname eth0 udp dport 51820 dnat to 192.168.1.190:51820

# Add FORWARD rule to allow forwarded WireGuard traffic
nft add rule inet filter forward iifname eth0 oifname eth1 udp dport 51820 ip daddr 192.168.1.190 ct state new,established counter accept
nft add rule inet filter forward iifname eth1 oifname eth0 udp sport 51820 ip saddr 192.168.1.190 ct state established counter accept
```

#### 3. Make Rules Persistent

Save the nftables ruleset:

```bash
# Save current ruleset
nft list ruleset > /etc/nftables.conf

# Ensure nftables service is enabled
systemctl enable nftables
systemctl restart nftables
```

#### 4. Verify Rules

```bash
# Check NAT rules
nft list table inet nat

# Check filter rules
nft list table inet filter

# Test from external host
nc -u -v YOUR_PUBLIC_IP 51820
```

### Method 2: Using iptables (Legacy)

If your firewall uses iptables instead of nftables:

#### 1. Add Port Forward Rules

```bash
# Add PREROUTING rule for DNAT
iptables -t nat -A PREROUTING -i eth0 -p udp --dport 51820 -j DNAT --to-destination 192.168.1.190:51820

# Add FORWARD rules to allow traffic
iptables -A FORWARD -i eth0 -o eth1 -p udp --dport 51820 -d 192.168.1.190 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i eth1 -o eth0 -p udp --sport 51820 -s 192.168.1.190 -m state --state ESTABLISHED,RELATED -j ACCEPT
```

#### 2. Make Rules Persistent

```bash
# Install iptables-persistent
apt-get update
apt-get install -y iptables-persistent

# Save rules
iptables-save > /etc/iptables/rules.v4

# Or use netfilter-persistent
netfilter-persistent save
```

#### 3. Verify Rules

```bash
# List NAT rules
iptables -t nat -L -n -v

# List FORWARD rules
iptables -L FORWARD -n -v

# Watch live traffic
iptables -L FORWARD -n -v --line-numbers
watch -n 1 'iptables -t nat -L PREROUTING -n -v'
```

### Method 3: Ansible Automation (Future Enhancement)

For infrastructure-as-code approach, the firewall role should be enhanced to support dynamic service port forwarding.

**Proposed Variable Structure:**

```yaml
# inventory/group_vars/all/firewall.yml
firewall_port_forwards:
  - name: wireguard-vpn
    protocol: udp
    external_port: 51820
    internal_ip: 192.168.1.190
    internal_port: 51820
    description: "WireGuard VPN Server"
```

**Implementation:** This would require updating `roles/firewall/tasks/main.yml` to iterate over `firewall_port_forwards` and generate nftables/iptables rules dynamically.

## Verification and Testing

### 1. Verify Port Forwarding from Firewall

```bash
# From firewall container, check if WireGuard port is reachable
pct exec 101 -- nc -u -v -w 1 192.168.1.190 51820
```

### 2. Test from External Network

```bash
# From a machine on the internet (not your local network)
nc -u -v YOUR_PUBLIC_IP 51820

# Or use nmap (if installed)
nmap -sU -p 51820 YOUR_PUBLIC_IP
```

### 3. Monitor Live Traffic

```bash
# On firewall, watch for WireGuard traffic
tcpdump -i eth0 udp port 51820 -n

# On WireGuard server, watch for incoming connections
pct exec 190 -- tcpdump -i eth0 udp port 51820 -n
```

### 4. Check WireGuard Handshakes

```bash
# On WireGuard server, check for successful handshakes
pct exec 190 -- wg show

# Look for "latest handshake" - should show recent timestamp when client connects
```

## Troubleshooting

### Issue: Port Forward Not Working

**Symptoms:** Clients cannot connect, handshake timeout

**Diagnosis:**
```bash
# Check if rules exist
nft list ruleset | grep 51820
# or
iptables -t nat -L -n | grep 51820

# Check if firewall is blocking
tcpdump -i eth0 udp port 51820 -n

# Verify WireGuard is listening
pct exec 190 -- ss -ulnp | grep 51820
```

**Common Causes:**
- Firewall rules not saved (lost on reboot)
- Rules in wrong order (REJECT/DROP rule before ACCEPT)
- Network interface names wrong (eth0 vs ens18)
- WireGuard service not running

**Solutions:**
```bash
# Restart nftables
systemctl restart nftables

# Restart WireGuard
pct exec 190 -- systemctl restart wg-quick@wg0

# Check logs
journalctl -u nftables -n 50
pct exec 190 -- journalctl -u wg-quick@wg0 -n 50
```

### Issue: Firewall Rules Lost After Reboot

**Symptoms:** Port forwarding works, but stops after container restart

**Solution:**
```bash
# Ensure nftables/iptables service is enabled
systemctl enable nftables
systemctl status nftables

# For iptables
systemctl enable netfilter-persistent
```

### Issue: Can Connect to VPN but Can't Reach Management Network

**Symptoms:** Handshake succeeds, but ping to 192.168.x.x fails

**Diagnosis:**
```bash
# On WireGuard server, check IP forwarding
pct exec 190 -- sysctl net.ipv4.ip_forward

# Check routing
pct exec 190 -- ip route show

# Check iptables NAT rules
pct exec 190 -- iptables -t nat -L -n -v
```

**Solution:** This is a routing issue on the WireGuard server, not firewall. Check WireGuard PostUp/PostDown rules in `/etc/wireguard/wg0.conf`.

## Security Considerations

### Rate Limiting

To prevent DoS attacks, consider rate limiting WireGuard port:

```bash
# nftables rate limiting
nft add rule inet filter input iifname eth0 udp dport 51820 limit rate 100/minute counter accept
nft add rule inet filter input iifname eth0 udp dport 51820 counter drop

# iptables rate limiting
iptables -A INPUT -i eth0 -p udp --dport 51820 -m limit --limit 100/minute -j ACCEPT
iptables -A INPUT -i eth0 -p udp --dport 51820 -j DROP
```

### Source IP Filtering (Optional)

If you know your users' IP ranges, restrict access:

```bash
# nftables - allow only from specific country/ASN (requires geoip module)
nft add rule inet filter input iifname eth0 ip saddr { 1.2.3.0/24, 5.6.7.0/24 } udp dport 51820 counter accept
nft add rule inet filter input iifname eth0 udp dport 51820 counter drop

# iptables
iptables -A INPUT -i eth0 -s 1.2.3.0/24 -p udp --dport 51820 -j ACCEPT
iptables -A INPUT -i eth0 -s 5.6.7.0/24 -p udp --dport 51820 -j ACCEPT
iptables -A INPUT -i eth0 -p udp --dport 51820 -j DROP
```

### Logging

Enable logging for security auditing:

```bash
# nftables - log new connections
nft add rule inet filter input iifname eth0 udp dport 51820 ct state new log prefix \"WireGuard-NEW: \" counter

# iptables
iptables -A INPUT -i eth0 -p udp --dport 51820 -m state --state NEW -j LOG --log-prefix "WireGuard-NEW: "
```

## Maintenance

### Backup Firewall Rules

```bash
# nftables
nft list ruleset > /root/nftables-backup-$(date +%Y%m%d).conf

# iptables
iptables-save > /root/iptables-backup-$(date +%Y%m%d).rules
```

### Restore Firewall Rules

```bash
# nftables
nft flush ruleset
nft -f /root/nftables-backup-YYYYMMDD.conf

# iptables
iptables-restore < /root/iptables-backup-YYYYMMDD.rules
```

### Remove WireGuard Rules

When tearing down WireGuard server:

```bash
# nftables - list rules with handles
nft -a list table inet nat
nft -a list table inet filter

# Delete by handle number
nft delete rule inet nat prerouting handle <HANDLE>
nft delete rule inet filter forward handle <HANDLE>

# iptables
iptables -t nat -D PREROUTING -i eth0 -p udp --dport 51820 -j DNAT --to-destination 192.168.1.190:51820
iptables -D FORWARD -i eth0 -o eth1 -p udp --dport 51820 -d 192.168.1.190 -j ACCEPT
iptables -D FORWARD -i eth1 -o eth0 -p udp --sport 51820 -s 192.168.1.190 -j ACCEPT
```

## References

- nftables Wiki: https://wiki.nftables.org/
- WireGuard Documentation: https://www.wireguard.com/
- Debian nftables Guide: https://wiki.debian.org/nftables
- iptables Tutorial: https://www.netfilter.org/documentation/

---

**Next Steps:**
1. Apply firewall rules using Method 1 or Method 2
2. Test connectivity from external network
3. Deploy WireGuard server: `ansible-playbook playbooks/wireguard-deploy.yml --ask-vault-pass`
4. Create client configurations: `./scripts/wireguard-gen-client.sh`
