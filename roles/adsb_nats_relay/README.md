# adsb_nats_relay

Ansible role to deploy ADS-B NATS relay service on viljo.se.

## Overview

Deploys three relay instances that publish ADS-B data to NATS JetStream:

| Container | Mode | Source | Sensor IDs |
|-----------|------|--------|------------|
| adsb-nats-relay | Y-splitter | ADSBHub worldwide | 4250-4750 |
| adsb-nats-relay-local | Direct SBS | Raspberry Pi Beast | 4750-5000 |
| adsb-nats-relay-api | Proxy | ADS-B.fi API | 5000-5250 |

## Architecture

```
ADSBHub ──► Y-splitter ──┬──► readsb
                         └──► NATS

Raspberry Pi ──► readsb ──► SBS output ──► local relay ──► NATS

ADS-B.fi API ──► api2sbs ──► proxy relay ──┬──► readsb
                                           └──► NATS
```

## Usage

```bash
ansible-playbook -i inventory/hosts.yml playbooks/adsb-nats-relay-deploy.yml
```

## NATS Endpoint

- Server: `nats://adsb-maps.viljo.se:4222`
- Mission ID: `1234567`
- Subjects: `mission.1234567.source.data`, `mission.1234567.config.data`

## maps-client Connection

Set environment variable before running maps-client:
```bash
MAPS_CONFIG_FILE=python/viljo_config.json ./setup/mac_os_dev_build_and_launch.sh
```

## Variables

See `defaults/main.yml` for all configuration options.

Key variables:
- `splitter_enabled`: Enable Y-splitter for ADSBHub
- `local_relay_enabled`: Enable relay for local Raspberry Pi data
- `api_relay_enabled`: Enable proxy relay for api2sbs
- `nats_mission_id`: NATS stream/mission identifier

## Dependencies

- `adsb_relay` role must be deployed first (provides readsb container)
- External network `adsb-relay_adsb_internal` must exist
