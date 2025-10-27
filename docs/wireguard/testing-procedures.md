# WireGuard VPN Testing Procedures

This document provides comprehensive testing procedures to verify the WireGuard VPN deployment meets all functional and non-functional requirements from the specification.

## Table of Contents

1. [Test Environment Setup](#test-environment-setup)
2. [Functional Testing](#functional-testing)
3. [Performance Testing](#performance-testing)
4. [Security Testing](#security-testing)
5. [Reliability Testing](#reliability-testing)
6. [User Story Validation](#user-story-validation)
7. [Success Criteria Verification](#success-criteria-verification)

---

## Test Environment Setup

### Prerequisites

- WireGuard server deployed (CT 190)
- Firewall configured for port forwarding
- At least one test client with WireGuard installed
- Access to Proxmox host for server-side verification
- External network access for client connection testing

### Test Clients

Prepare test clients on multiple platforms:

- [ ] Linux (Debian/Ubuntu)
- [ ] macOS
- [ ] Windows
- [ ] iOS (optional)
- [ ] Android (optional)

### Test Tools

Install on test clients:

```bash
# Linux/macOS
sudo apt install wireguard-tools iputils-ping iperf3 mtr traceroute

# macOS (via Homebrew)
brew install wireguard-tools iperf3 mtr

# Windows
# Download WireGuard from wireguard.com/install
# Download iperf3 from iperf.fr
```

---

## Functional Testing

### Test 1: Container Deployment

**Objective:** Verify WireGuard container is properly created and configured

**Steps:**

1. Check container exists:
   ```bash
   ssh root@proxmox-host pct list | grep 190
   ```

2. Verify container configuration:
   ```bash
   ssh root@proxmox-host cat /etc/pve/lxc/190.conf
   ```

3. Check container status:
   ```bash
   ssh root@proxmox-host pct status 190
   ```

**Expected Results:**
- Container 190 exists
- Status: running
- Configuration includes: unprivileged=1, onboot=1, nesting=1
- Network: vmbr0 bridge with IP 192.168.1.190/24

**Pass Criteria:**
- [ ] Container exists and is running
- [ ] Unprivileged container (security requirement)
- [ ] Onboot enabled (auto-start requirement)
- [ ] Nesting enabled (WireGuard requirement)

---

### Test 2: WireGuard Service Status

**Objective:** Verify WireGuard service is running and enabled

**Steps:**

1. Check service status:
   ```bash
   ssh root@proxmox-host pct exec 190 -- systemctl status wg-quick@wg0
   ```

2. Verify service is enabled:
   ```bash
   ssh root@proxmox-host pct exec 190 -- systemctl is-enabled wg-quick@wg0
   ```

3. Check WireGuard interface:
   ```bash
   ssh root@proxmox-host pct exec 190 -- ip addr show wg0
   ```

**Expected Results:**
- Service state: active (running)
- Service enabled: yes
- Interface wg0 exists with IP 192.168.100.1/24

**Pass Criteria:**
- [ ] Service is active
- [ ] Service is enabled (starts on boot)
- [ ] Interface wg0 has correct IP address

---

### Test 3: Peer Configuration

**Objective:** Verify peer configurations are correctly applied

**Steps:**

1. Check peer list:
   ```bash
   ssh root@proxmox-host pct exec 190 -- wg show wg0 peers
   ```

2. Verify peer details:
   ```bash
   ssh root@proxmox-host pct exec 190 -- wg show wg0
   ```

3. Check configuration file:
   ```bash
   ssh root@proxmox-host pct exec 190 -- cat /etc/wireguard/wg0.conf
   ```

**Expected Results:**
- Configured peers match Ansible inventory
- Each peer has unique public key
- Each peer has unique allowed_ips
- Configuration file has correct format

**Pass Criteria:**
- [ ] All peers from inventory are present
- [ ] No duplicate public keys
- [ ] No overlapping allowed_ips
- [ ] Configuration file is readable only by root (permissions 600)

---

### Test 4: Client Connection (Single Peer)

**Objective:** Verify a single client can successfully connect to VPN

**Steps:**

1. Import client configuration:
   ```bash
   sudo cp test-client.conf /etc/wireguard/wg0.conf
   sudo chmod 600 /etc/wireguard/wg0.conf
   ```

2. Start VPN connection:
   ```bash
   sudo wg-quick up wg0
   ```

3. Check client interface:
   ```bash
   wg show
   ip addr show wg0
   ```

4. Verify handshake on server:
   ```bash
   ssh root@proxmox-host pct exec 190 -- wg show wg0
   ```

5. Measure connection time:
   ```bash
   time sudo wg-quick up wg0
   ```

**Expected Results:**
- Connection established without errors
- Client has VPN IP (e.g., 192.168.100.10/32)
- Server shows "latest handshake: X seconds ago"
- Connection time <5 seconds

**Pass Criteria:**
- [ ] Client successfully connects
- [ ] Handshake completes
- [ ] Connection time <5 seconds (SC-001)
- [ ] No error messages

---

### Test 5: Multi-Peer Connections

**Objective:** Verify multiple peers can connect simultaneously

**Steps:**

1. Connect first peer from location A
2. Connect second peer from location B
3. Connect third peer from location C

4. Verify all peers on server:
   ```bash
   ssh root@proxmox-host pct exec 190 -- wg show wg0
   ```

5. Check for IP conflicts:
   ```bash
   ssh root@proxmox-host pct exec 190 -- wg show wg0 | grep "allowed ips"
   ```

**Expected Results:**
- All peers show recent handshakes
- Each peer has unique VPN IP
- No connection errors or conflicts
- Server handles 3+ concurrent connections

**Pass Criteria:**
- [ ] All peers connect successfully
- [ ] No IP address conflicts
- [ ] All handshakes are recent (<3 minutes)
- [ ] No performance degradation

---

### Test 6: Network Routing

**Objective:** Verify traffic routes correctly through VPN

**Steps:**

1. Ping VPN gateway from client:
   ```bash
   ping -c 5 192.168.100.1
   ```

2. Ping management network gateway:
   ```bash
   ping -c 5 192.168.1.1
   ```

3. Ping Proxmox host:
   ```bash
   ping -c 5 192.168.1.3
   ```

4. Ping WireGuard server IP:
   ```bash
   ping -c 5 192.168.1.190
   ```

5. Verify DMZ is NOT accessible (security requirement):
   ```bash
   ping -c 3 172.16.10.101
   # Should fail or timeout
   ```

6. Check routing table:
   ```bash
   ip route show
   ```

**Expected Results:**
- VPN gateway (192.168.100.1) is reachable
- Management network (192.168.0.0/16) is accessible
- DMZ network (172.16.10.0/24) is NOT accessible
- Route for 192.168.0.0/16 via wg0 interface exists

**Pass Criteria:**
- [ ] VPN gateway responds to ping (0% packet loss)
- [ ] Management network is accessible
- [ ] DMZ is NOT accessible (security requirement)
- [ ] Routing table is correct

---

### Test 7: DNS Resolution

**Objective:** Verify DNS works through VPN (if configured)

**Steps:**

1. Check DNS servers:
   ```bash
   cat /etc/resolv.conf
   ```

2. Test DNS resolution:
   ```bash
   nslookup proxmox.infra.local
   dig proxmox.infra.local
   ```

3. Test external DNS:
   ```bash
   nslookup google.com
   ```

**Expected Results:**
- DNS servers configured (192.168.1.1 or custom)
- Internal hostnames resolve
- External hostnames resolve

**Pass Criteria:**
- [ ] DNS configuration is present
- [ ] Internal DNS resolution works (if configured)
- [ ] External DNS resolution works

---

## Performance Testing

### Test 8: Connection Latency

**Objective:** Verify VPN adds <10ms latency overhead (SC-007)

**Steps:**

1. Measure baseline latency (without VPN):
   ```bash
   ping -c 50 192.168.1.1
   ```

2. Connect to VPN and measure again:
   ```bash
   sudo wg-quick up wg0
   ping -c 50 192.168.1.1
   ```

3. Calculate latency overhead:
   ```bash
   # Compare average RTT from both tests
   # Overhead = VPN_RTT - Direct_RTT
   ```

**Expected Results:**
- Direct latency: X ms
- VPN latency: X + Y ms
- Overhead (Y): <10ms

**Pass Criteria:**
- [ ] Latency overhead is <10ms (SC-007)
- [ ] No significant jitter introduced

---

### Test 9: Throughput

**Objective:** Verify throughput ≥100 Mbps (SC-004)

**Steps:**

1. Start iperf3 server on WireGuard container:
   ```bash
   ssh root@proxmox-host pct exec 190 -- iperf3 -s
   ```

2. Run iperf3 client from VPN:
   ```bash
   iperf3 -c 192.168.1.190 -t 30 -i 5
   ```

3. Test both directions:
   ```bash
   # Upload
   iperf3 -c 192.168.1.190 -t 30

   # Download
   iperf3 -c 192.168.1.190 -t 30 -R
   ```

**Expected Results:**
- Upload: ≥100 Mbps
- Download: ≥100 Mbps
- Consistent throughput throughout test

**Pass Criteria:**
- [ ] Upload throughput ≥100 Mbps (SC-004)
- [ ] Download throughput ≥100 Mbps (SC-004)
- [ ] No significant drops or interruptions

---

### Test 10: Scalability

**Objective:** Verify server supports ≥20 concurrent peers (SC-003)

**Steps:**

1. Generate 20 peer configurations:
   ```bash
   for i in {2..21}; do
     ./scripts/wireguard-gen-client.sh \
       "test-peer-$i" \
       "192.168.100.$i" \
       "$SERVER_PUBLIC_KEY" \
       "$ENDPOINT"
   done
   ```

2. Add all peers to inventory and redeploy

3. Connect all 20 peers (use automation or multiple devices)

4. Monitor server resources:
   ```bash
   ssh root@proxmox-host pct exec 190 -- top
   ssh root@proxmox-host pct exec 190 -- wg show wg0 | grep peer | wc -l
   ```

5. Test performance with 20 peers connected

**Expected Results:**
- Server handles 20+ concurrent connections
- CPU usage <50%
- Memory usage <500MB
- All peers maintain handshakes

**Pass Criteria:**
- [ ] Server supports ≥20 concurrent peers (SC-003)
- [ ] No performance degradation
- [ ] All peers can access management network

---

## Security Testing

### Test 11: Authentication

**Objective:** Verify only authorized peers can connect

**Steps:**

1. Attempt connection with invalid private key:
   ```bash
   # Edit client config with random private key
   wg genkey > invalid_private.key
   # Replace PrivateKey in config with invalid key
   sudo wg-quick up wg0
   ```

2. Attempt connection with valid key but not configured on server:
   ```bash
   # Generate new keypair not in server config
   wg genkey | tee new_private.key | wg pubkey > new_public.key
   # Create client config with new keys
   sudo wg-quick up wg0
   ```

3. Verify server rejects connections:
   ```bash
   ssh root@proxmox-host pct exec 190 -- wg show wg0
   # Should not show unauthorized peer
   ```

**Expected Results:**
- Invalid keys: Connection fails, no handshake
- Unconfigured keys: Connection rejected
- Server logs show no unauthorized handshakes

**Pass Criteria:**
- [ ] Invalid private keys are rejected
- [ ] Unconfigured public keys are rejected
- [ ] Only authorized peers can complete handshake

---

### Test 12: Encryption

**Objective:** Verify traffic is encrypted (ChaCha20-Poly1305)

**Steps:**

1. Check cipher in use:
   ```bash
   ssh root@proxmox-host pct exec 190 -- wg show wg0
   # WireGuard always uses ChaCha20-Poly1305
   ```

2. Monitor encrypted traffic:
   ```bash
   # On WireGuard server
   ssh root@proxmox-host pct exec 190 -- tcpdump -i eth0 udp port 51820 -X -c 10
   # Traffic should be encrypted (unreadable payload)
   ```

3. Verify handshake protocol:
   ```bash
   # Check latest handshake in logs
   ssh root@proxmox-host pct exec 190 -- journalctl -u wg-quick@wg0 | grep -i handshake
   ```

**Expected Results:**
- Cipher: ChaCha20-Poly1305 (WireGuard default)
- Traffic is encrypted (not plaintext in tcpdump)
- Handshakes complete successfully

**Pass Criteria:**
- [ ] Modern encryption in use (ChaCha20-Poly1305)
- [ ] Traffic is encrypted
- [ ] No plaintext leakage

---

### Test 13: Network Segmentation

**Objective:** Verify VPN only accesses management network, NOT DMZ

**Steps:**

1. From VPN client, attempt to access DMZ:
   ```bash
   # Try to ping DMZ gateway
   ping -c 5 172.16.10.101

   # Try to connect to DMZ services
   curl -m 5 http://172.16.10.101
   nc -zv 172.16.10.101 80
   ```

2. Verify management network is accessible:
   ```bash
   ping -c 5 192.168.1.1
   curl http://192.168.1.3:8006  # Proxmox UI
   ```

3. Check routing prevents DMZ access:
   ```bash
   ip route show | grep 172.16
   # Should NOT show route to DMZ
   ```

**Expected Results:**
- DMZ (172.16.10.0/24) is NOT accessible
- Management network (192.168.0.0/16) IS accessible
- No route to DMZ in client routing table

**Pass Criteria:**
- [ ] DMZ is NOT accessible (security requirement)
- [ ] Management network IS accessible
- [ ] Network segmentation enforced

---

## Reliability Testing

### Test 14: Service Auto-Start

**Objective:** Verify WireGuard starts automatically on boot

**Steps:**

1. Reboot WireGuard container:
   ```bash
   ssh root@proxmox-host pct reboot 190
   ```

2. Wait for boot (60 seconds):
   ```bash
   sleep 60
   ```

3. Check service status:
   ```bash
   ssh root@proxmox-host pct exec 190 -- systemctl is-active wg-quick@wg0
   ```

4. Measure boot time:
   ```bash
   # Time from reboot to service active
   ssh root@proxmox-host pct exec 190 -- systemd-analyze
   ```

5. Test client connection after reboot:
   ```bash
   sudo wg-quick down wg0
   sudo wg-quick up wg0
   wg show
   ```

**Expected Results:**
- Container auto-starts after host reboot
- WireGuard service auto-starts within 60 seconds
- Service active and accepting connections
- Clients can reconnect automatically

**Pass Criteria:**
- [ ] Container starts automatically (onboot=1)
- [ ] Service starts within 60 seconds
- [ ] Clients can reconnect without manual intervention

---

### Test 15: Connection Persistence

**Objective:** Verify connections persist through network disruptions

**Steps:**

1. Establish VPN connection and start continuous ping:
   ```bash
   sudo wg-quick up wg0
   ping 192.168.100.1 | ts '[%Y-%m-%d %H:%M:%S]'
   ```

2. Simulate network disruption:
   ```bash
   # Disconnect and reconnect WiFi/Ethernet
   # Or temporarily disconnect VPN client from network for 30 seconds
   ```

3. Observe connection recovery:
   ```bash
   # Ping should resume automatically
   # Check wg show for handshake recovery
   wg show
   ```

4. Verify persistent keepalive:
   ```bash
   # Check server shows persistent keepalive
   ssh root@proxmox-host pct exec 190 -- wg show wg0 | grep "keepalive"
   ```

**Expected Results:**
- Connection recovers automatically after disruption
- Persistent keepalive (25 seconds) maintains NAT traversal
- No manual reconnection required
- Maximum downtime <30 seconds

**Pass Criteria:**
- [ ] Connection persists through network disruption
- [ ] Keepalive maintains NAT traversal
- [ ] Automatic recovery without user intervention

---

### Test 16: Stability Test (1 Hour)

**Objective:** Verify 99.5% uptime over extended period

**Steps:**

1. Start long-running stability test:
   ```bash
   # Terminal 1: Continuous ping
   sudo wg-quick up wg0
   ping -i 5 192.168.100.1 | tee stability-test.log | ts '[%Y-%m-%d %H:%M:%S]'

   # Terminal 2: Monitor handshakes
   watch -n 30 'ssh root@proxmox-host pct exec 190 -- wg show wg0'

   # Terminal 3: Monitor bandwidth
   watch -n 60 'ssh root@proxmox-host pct exec 190 -- wg show wg0 transfer'
   ```

2. Let run for 1 hour (720 pings at 5s interval)

3. Analyze results:
   ```bash
   # Count successful pings
   grep "time=" stability-test.log | wc -l

   # Count timeouts
   grep "timeout" stability-test.log | wc -l

   # Calculate uptime percentage
   # Uptime = (successful_pings / total_pings) * 100
   ```

**Expected Results:**
- Total pings: 720
- Successful: ≥716 (99.5%)
- Timeouts: ≤4 (0.5%)
- Consistent latency throughout
- No disconnections or service failures

**Pass Criteria:**
- [ ] Uptime ≥99.5% (SC-002)
- [ ] No service crashes
- [ ] Consistent performance throughout test

---

## User Story Validation

### User Story 1: Secure Remote Access to Infrastructure

**Acceptance Criteria:**

1. ✓ User connects via WireGuard client → Tunnel establishes within 5 seconds
2. ✓ VPN is connected → User can access internal services (192.168.0.0/16)
3. ✓ User disconnects client → Tunnel tears down cleanly
4. ✓ User tries invalid key → Authentication fails and access denied

**Test:**
```bash
# TC1: Connection time
time sudo wg-quick up wg0  # Should be <5 seconds

# TC2: Access management network
ping -c 5 192.168.1.3  # Should succeed

# TC3: Clean teardown
sudo wg-quick down wg0  # Should complete without errors
ip route show | grep 192.168.100  # Routes should be removed

# TC4: Invalid key
# Use test case from Test 11
```

---

### User Story 2: Multi-Peer VPN Network

**Acceptance Criteria:**

1. ✓ Add new peer → Peer added without disrupting existing connections
2. ✓ Multiple peers connect → Each receives correct IP without conflicts
3. ✓ Peer has specific allowed IPs → Split tunneling works correctly
4. ✓ Remove peer → Peer configuration deleted, client can't connect

**Test:**
```bash
# TC1: Add peer without disruption
# Keep peer 1 connected and pinging
# Add peer 2 to inventory and redeploy
# Verify peer 1 maintains connection

# TC2: Multiple peers
# Connect 3+ peers simultaneously
ssh root@proxmox-host pct exec 190 -- wg show wg0
# Verify unique IPs and all have recent handshakes

# TC3: Split tunneling
# Configure peer with specific AllowedIPs (e.g., only 192.168.1.0/24)
# Verify only that subnet is routed through VPN

# TC4: Remove peer
# Remove peer from inventory, redeploy
# Attempt to connect with removed peer
# Should fail to handshake
```

---

### User Story 3: Persistent VPN Service

**Acceptance Criteria:**

1. ✓ Proxmox host reboots → Container starts within 60 seconds
2. ✓ Check service status → wg-quick service is active and enabled
3. ✓ Network disruption → Connections reestablish via keepalive
4. ✓ Service crashes → Systemd restarts automatically (if configured)

**Test:**
```bash
# TC1: Auto-start on boot
# See Test 14

# TC2: Service status
ssh root@proxmox-host pct exec 190 -- systemctl is-active wg-quick@wg0
ssh root@proxmox-host pct exec 190 -- systemctl is-enabled wg-quick@wg0

# TC3: Network disruption recovery
# See Test 15

# TC4: Service restart on failure (optional enhancement)
# Kill WireGuard process
ssh root@proxmox-host pct exec 190 -- pkill -9 wg
# Check if systemd restarts it
sleep 5
ssh root@proxmox-host pct exec 190 -- systemctl status wg-quick@wg0
```

---

## Success Criteria Verification

### SC-001: Connection Time <5 Seconds

**Test:**
```bash
time sudo wg-quick up wg0
```

**Pass:** real time <5.0s

---

### SC-002: 99.5% Uptime

**Test:** See Test 16 (Stability Test)

**Pass:** Uptime ≥99.5% over 1 hour

---

### SC-003: Support ≥20 Concurrent Peers

**Test:** See Test 10 (Scalability)

**Pass:** 20+ peers connected simultaneously without degradation

---

### SC-004: Throughput ≥100 Mbps

**Test:** See Test 9 (Throughput)

**Pass:** iperf3 shows ≥100 Mbps in both directions

---

### SC-005: Peer Config Changes <2 Minutes

**Test:**
```bash
time ansible-playbook playbooks/wireguard-deploy.yml --ask-vault-pass
```

**Pass:** real time <2m 0s

---

### SC-006: Peer Onboarding <10 Minutes

**Test:** Time the complete process:
1. Generate client keys
2. Create client config
3. Add to inventory
4. Redeploy server
5. Distribute config
6. Client connects

**Pass:** Total time <10 minutes

---

### SC-007: Latency Overhead <10ms

**Test:** See Test 8 (Connection Latency)

**Pass:** VPN_latency - Direct_latency <10ms

---

### SC-008: 95% First-Try Connection Success

**Test:** Track connection attempts over 20 peer additions

**Pass:** ≥19 out of 20 peers connect successfully on first try

---

## Test Report Template

```
WireGuard VPN Test Report

Date: ___________________
Tester: ___________________
Environment: ___________________

Functional Tests:
[ ] Test 1: Container Deployment - PASS/FAIL
[ ] Test 2: WireGuard Service Status - PASS/FAIL
[ ] Test 3: Peer Configuration - PASS/FAIL
[ ] Test 4: Client Connection - PASS/FAIL
[ ] Test 5: Multi-Peer Connections - PASS/FAIL
[ ] Test 6: Network Routing - PASS/FAIL
[ ] Test 7: DNS Resolution - PASS/FAIL

Performance Tests:
[ ] Test 8: Connection Latency - PASS/FAIL (___ms overhead)
[ ] Test 9: Throughput - PASS/FAIL (___Mbps upload, ___Mbps download)
[ ] Test 10: Scalability - PASS/FAIL (___concurrent peers)

Security Tests:
[ ] Test 11: Authentication - PASS/FAIL
[ ] Test 12: Encryption - PASS/FAIL
[ ] Test 13: Network Segmentation - PASS/FAIL

Reliability Tests:
[ ] Test 14: Service Auto-Start - PASS/FAIL
[ ] Test 15: Connection Persistence - PASS/FAIL
[ ] Test 16: Stability Test - PASS/FAIL (___% uptime)

User Stories:
[ ] US1: Secure Remote Access - PASS/FAIL
[ ] US2: Multi-Peer Network - PASS/FAIL
[ ] US3: Persistent Service - PASS/FAIL

Success Criteria:
[ ] SC-001: Connection <5s - PASS/FAIL (___s)
[ ] SC-002: 99.5% uptime - PASS/FAIL (___%)
[ ] SC-003: 20+ peers - PASS/FAIL (___peers)
[ ] SC-004: 100+ Mbps - PASS/FAIL (___Mbps)
[ ] SC-005: Config <2min - PASS/FAIL (___s)
[ ] SC-006: Onboarding <10min - PASS/FAIL (___min)
[ ] SC-007: Latency <10ms - PASS/FAIL (___ms)
[ ] SC-008: 95% success - PASS/FAIL (___%)

Overall Result: PASS / FAIL

Notes:
_________________________________________________
_________________________________________________
```

---

**Next Steps:**
- Execute all tests
- Document results
- Address any failures
- Retest after fixes
- Sign off when all tests pass
