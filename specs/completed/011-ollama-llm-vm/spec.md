# Spec 011: Ollama LLM VM

**Status**: ✅ Completed
**Deployed**: 2025-11-23
**VM ID**: 201
**Priority**: Medium
**Complexity**: Medium

## Overview

Deploy a dedicated QEMU/KVM virtual machine running Ubuntu 24.04 LTS with Ollama LLM inference server for local AI workloads. The VM provides on-premise LLM capabilities accessible from the Proxmox infrastructure without requiring external API services.

## Objectives

- ✅ Deploy Ubuntu 24.04 LTS VM on Proxmox with proper disk configuration
- ✅ Configure VM network on internal vmbr3 bridge (172.31.31.0/24)
- ✅ Install and configure Ollama LLM inference server
- ✅ Test functionality with small language model (qwen2.5:0.5b)
- ✅ Document VM configuration and access patterns
- ✅ Add to infrastructure inventory and service registry

## Requirements

### Functional Requirements

**FR-001**: VM must boot successfully with Ubuntu 24.04 LTS
**FR-002**: VM must have static IP address on vmbr3 network
**FR-003**: Ollama service must run on startup and be accessible via API
**FR-004**: VM must be accessible via SSH from Proxmox host
**FR-005**: VM must support model downloads and inference operations

### Non-Functional Requirements

**NFR-001**: VM resources: 16GB RAM, 8 CPU cores, 64GB disk
**NFR-002**: Network isolation on internal bridge (no direct internet access required)
**NFR-003**: Cloud-init for automated initial configuration
**NFR-004**: CPU-only operation (no GPU required)

## Architecture

### VM Configuration

**Type**: QEMU/KVM Virtual Machine
**OS**: Ubuntu 24.04 LTS (Jammy)
**Kernel**: 6.8.0-87-generic
**VM ID**: 201

**Resources**:
- CPU: 8 cores
- RAM: 16GB
- Disk: 64GB (SCSI, local-lvm)
- Boot: scsi0 (disk boot, not network)

**Network**:
- Bridge: vmbr3 (172.31.31.0/24)
- IP: 172.31.31.201/24 (static via cloud-init)
- Gateway: 172.31.31.1 (Proxmox host)

**Cloud-init**:
- Drive: ide2 (cloud-init configuration)
- User: root
- SSH: Keys from Proxmox host `/root/.ssh/authorized_keys`

### Software Stack

**Ollama LLM Server**:
- Version: 0.13.0
- Installation: Official install script (`https://ollama.com/install.sh`)
- Service: systemd (enabled on boot)
- API: localhost:11434 (default)

**Test Model**:
- Model: qwen2.5:0.5b
- Size: 397MB
- Parameters: 500M
- Purpose: Verification testing and lightweight inference

### Network Topology

```
Internet
   ↓
vmbr2 (WAN) → LXC 200 (Containers) → Docker Services

Proxmox Host (192.168.1.3)
   ↓ vmbr3 (172.31.31.0/24 - Internal)
   ↓
VM 201 (Ollama) - 172.31.31.201/24
```

**Access Pattern**:
- External → Proxmox Host (via SSH) → VM 201 (via SSH/API)
- VM is NOT directly accessible from external networks
- All access routed through Proxmox host on vmbr3 bridge

## Implementation

### Phase 1: VM Disk Configuration ✅

**Problem**: VM 201 existed but had broken disk configuration:
- scsi0 pointed to 4MB EFI disk (wrong device)
- Boot order set to network boot (net0) instead of disk
- 3.5GB disk marked as "unused0" (not attached)
- No bootable OS installed

**Solution**:
1. Stop VM: `qm stop 201`
2. Remove broken scsi0: `qm set 201 --delete scsi0`
3. Download Ubuntu cloud image: `ubuntu-24.04-cloudimg-amd64.img`
4. Import as new disk: `qm importdisk 201 /path/to/image local-lvm`
5. Attach as scsi0: `qm set 201 --scsi0 local-lvm:vm-201-disk-2`
6. Resize to 64GB: `qm resize 201 scsi0 +60G`
7. Change boot order: `qm set 201 --boot order=scsi0`

**Result**: VM has bootable 64GB disk with Ubuntu cloud image

### Phase 2: Cloud-init Configuration ✅

**Configuration**:
1. Add cloud-init drive: `qm set 201 --ide2 local-lvm:cloudinit`
2. Set static IP: `qm set 201 --ipconfig0 ip=172.31.31.201/24,gw=172.31.31.1`
3. Set cloud-init user: `qm set 201 --ciuser root`
4. Copy SSH keys: `qm set 201 --sshkeys /root/.ssh/authorized_keys`

**Benefits**:
- Automated initial OS configuration
- SSH access from Proxmox host without password
- Static IP assignment (no DHCP needed)
- Repeatable deployment process

### Phase 3: Ubuntu Installation ✅

**Process**:
1. Start VM: `qm start 201`
2. Ubuntu 24.04 boots automatically via cloud-init
3. Verify network: `ping -c 3 172.31.31.201` (from Proxmox host)
4. Verify SSH: `ssh root@172.31.31.201` (from Proxmox host)

**Verification**:
```bash
# Check OS version
ssh root@172.31.31.201 'lsb_release -a'
# Ubuntu 24.04 LTS (Jammy)

# Check disk space
ssh root@172.31.31.201 'df -h /'
# 61GB available

# Check network
ssh root@172.31.31.201 'ip addr show'
# 172.31.31.201/24 on eth0
```

### Phase 4: Ollama Installation ✅

**Installation**:
```bash
ssh root@172.31.31.201 'curl -fsSL https://ollama.com/install.sh | sh'
```

**Verification**:
```bash
# Check version
ssh root@172.31.31.201 'ollama --version'
# ollama version is 0.13.0

# Check service status
ssh root@172.31.31.201 'systemctl status ollama'
# Active: active (running)

# Check enabled on boot
ssh root@172.31.31.201 'systemctl is-enabled ollama'
# enabled
```

### Phase 5: Functionality Testing ✅

**Model Download**:
```bash
ssh root@172.31.31.201 'ollama pull qwen2.5:0.5b'
# Successfully pulled model (397MB)
```

**Inference Testing**:
```bash
# Test 1: Basic math
ssh root@172.31.31.201 'ollama run qwen2.5:0.5b "What is 2+2?"'
# Response: Correct answer about addition

# Test 2: Calculation verification
ssh root@172.31.31.201 'ollama run qwen2.5:0.5b "Calculate 15 + 27"'
# Response: 42 ✅
```

**Result**: Ollama inference working correctly

### Phase 6: Documentation ✅

**Updated Files**:
1. `inventory/group_vars/all/services.yml`: Added to infrastructure_services_internal
2. `docs/architecture/container-mapping.md`: Added VM inventory section
3. `docs/getting-started.md`: Added Ollama to service list
4. `specs/README.md`: Added to completed specs

## Verification

### Health Checks

**VM Status**:
```bash
ssh root@192.168.1.3 "qm status 201"
# Expected: status: running
```

**Network Connectivity**:
```bash
ssh root@192.168.1.3 "ping -c 3 172.31.31.201"
# Expected: 0% packet loss
```

**SSH Access**:
```bash
ssh root@192.168.1.3 "ssh root@172.31.31.201 'hostname'"
# Expected: ollama
```

**Ollama Service**:
```bash
ssh root@192.168.1.3 "ssh root@172.31.31.201 'systemctl is-active ollama'"
# Expected: active
```

**Model Inference**:
```bash
ssh root@192.168.1.3 "ssh root@172.31.31.201 'ollama list'"
# Expected: qwen2.5:0.5b listed
```

### Acceptance Criteria

- [x] VM boots successfully with Ubuntu 24.04
- [x] Network configured correctly (172.31.31.201/24)
- [x] SSH access working from Proxmox host
- [x] Ollama service running and enabled on boot
- [x] Model download working (qwen2.5:0.5b)
- [x] Inference working correctly (tested with calculations)
- [x] Documentation updated with configuration
- [x] Service registered in inventory

## Operations

### Starting/Stopping VM

```bash
# Start VM
ssh root@192.168.1.3 "qm start 201"

# Stop VM
ssh root@192.168.1.3 "qm stop 201"

# Restart VM
ssh root@192.168.1.3 "qm restart 201"

# Check status
ssh root@192.168.1.3 "qm status 201"
```

### Accessing Ollama

```bash
# SSH to VM
ssh root@192.168.1.3 "ssh root@172.31.31.201"

# Run model inference
ssh root@192.168.1.3 "ssh root@172.31.31.201 'ollama run qwen2.5:0.5b \"your prompt\"'"

# List downloaded models
ssh root@192.168.1.3 "ssh root@172.31.31.201 'ollama list'"

# Check service logs
ssh root@192.168.1.3 "ssh root@172.31.31.201 'journalctl -u ollama -f'"
```

### Managing Models

```bash
# Pull new model
ssh root@192.168.1.3 "ssh root@172.31.31.201 'ollama pull MODEL_NAME'"

# Delete model
ssh root@192.168.1.3 "ssh root@172.31.31.201 'ollama rm MODEL_NAME'"

# Show model details
ssh root@192.168.1.3 "ssh root@172.31.31.201 'ollama show MODEL_NAME'"
```

### Resource Monitoring

```bash
# Check VM resource usage in Proxmox
ssh root@192.168.1.3 "qm status 201 -verbose"

# Check disk usage
ssh root@192.168.1.3 "ssh root@172.31.31.201 'df -h'"

# Check memory usage
ssh root@192.168.1.3 "ssh root@172.31.31.201 'free -h'"

# Monitor in real-time
ssh root@192.168.1.3 "ssh root@172.31.31.201 'htop'"
```

## Troubleshooting

### VM Won't Boot

**Symptoms**: VM status shows stopped, won't start

**Diagnosis**:
```bash
# Check VM config
ssh root@192.168.1.3 "qm config 201"

# Check boot order
ssh root@192.168.1.3 "qm config 201 | grep boot"
# Expected: boot: order=scsi0
```

**Fix**: Ensure boot order is set to scsi0, not net0

### Network Not Working

**Symptoms**: Cannot ping VM from Proxmox host

**Diagnosis**:
```bash
# Check VM network config
ssh root@192.168.1.3 "qm config 201 | grep net"

# Check vmbr3 status on Proxmox
ssh root@192.168.1.3 "ip addr show vmbr3"
```

**Fix**: Verify vmbr3 bridge is up and VM is connected

### Ollama Service Not Running

**Symptoms**: Service inactive or failed

**Diagnosis**:
```bash
# Check service status
ssh root@192.168.1.3 "ssh root@172.31.31.201 'systemctl status ollama'"

# Check logs
ssh root@192.168.1.3 "ssh root@172.31.31.201 'journalctl -u ollama -n 50'"
```

**Fix**: Restart service or check logs for errors

### SSH Access Denied

**Symptoms**: Cannot SSH to VM from Proxmox host

**Diagnosis**:
```bash
# Check if VM is running
ssh root@192.168.1.3 "qm status 201"

# Test network connectivity
ssh root@192.168.1.3 "ping -c 3 172.31.31.201"

# Check SSH keys
ssh root@192.168.1.3 "qm cloudinit dump 201 user"
```

**Fix**: Verify SSH keys are configured in cloud-init

## Future Enhancements

### Potential Improvements

1. **GPU Support**: Add GPU passthrough for faster inference
2. **Model Management**: Ansible playbook for model deployment
3. **API Exposure**: Expose Ollama API to select internal services
4. **Monitoring**: Add Prometheus metrics for inference stats
5. **Backup**: Automated snapshots of VM state and models
6. **Multi-Model**: Pre-load multiple models for different use cases

### Model Recommendations

**Small Models** (< 1GB):
- qwen2.5:0.5b (397MB) - Already deployed
- phi3:mini (2.3GB) - Microsoft, good reasoning

**Medium Models** (1-5GB):
- llama3.2:3b (2GB) - Meta, general purpose
- mistral:7b (4.1GB) - Strong performance

**Large Models** (> 5GB):
- llama3.1:8b (4.7GB) - Latest Meta model
- mixtral:8x7b (26GB) - Mixture of experts (requires more RAM)

## Security Considerations

- VM is isolated on internal vmbr3 network (not exposed to internet)
- SSH access requires keys from Proxmox host (no password auth)
- Ollama API runs on localhost only (not exposed on network)
- VM resources are limited by Proxmox allocation
- No automatic model updates (manual management required)

## Lessons Learned

1. **Cloud-init is essential**: Automated configuration saves significant time
2. **Boot order matters**: Network boot caused confusion initially
3. **Disk sizing**: Start with adequate disk space (64GB) for multiple models
4. **Network isolation**: vmbr3 internal network provides good security boundary
5. **Testing is critical**: Small model (qwen2.5:0.5b) perfect for verification

## Related Documentation

- [Container Mapping](../../docs/architecture/container-mapping.md)
- [Getting Started Guide](../../docs/getting-started.md)
- [Services Inventory](../../inventory/group_vars/all/services.yml)
- [Ollama Official Docs](https://github.com/ollama/ollama)

## Changelog

**2025-11-23**: VM deployed and fully operational
- Fixed broken disk configuration
- Installed Ubuntu 24.04 via cloud-init
- Installed Ollama v0.13.0
- Tested with qwen2.5:0.5b model
- Documentation completed
- Spec marked as completed

---

**Spec Owner**: Infrastructure Team
**Deployment Date**: 2025-11-23
**Last Updated**: 2025-11-23
