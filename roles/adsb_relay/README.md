# adsb_relay

Ansible role to deploy ADS-B data aggregation service on viljo.se.

## Overview

Deploys readsb and api2sbs containers to aggregate ADS-B data from multiple sources:

1. **Raspberry Pi** - Local antenna with Beast TCP output (real-time, 1Hz)
2. **ADSBHub** - Worldwide aggregated feed via Y-splitter (see adsb_nats_relay)
3. **ADS-B.fi API** - Regional data via api2sbs container
4. **PingStation** - External SBS input on port 30006

## Architecture

```
Raspberry Pi:30005 ──► readsb (Beast input)

ADSBHub ──► Y-splitter ──► readsb:32006 (SBS input)

ADS-B.fi API ──► api2sbs ──► proxy ──► readsb:32006 (SBS input)

PingStation ──► readsb:30006 (SBS input)

                          readsb
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
         Beast:30005   SBS:30003    Web UI:8078
              │             │             │
              ▼             ▼             ▼
         external      NATS relay   https://adsb.viljo.se
```

## Usage

```bash
ansible-playbook -i inventory/hosts.yml playbooks/adsb-relay-deploy.yml
```

## Endpoints

- Web UI: https://adsb.viljo.se
- Beast TCP: adsb.viljo.se:30005
- SBS Input (PingStation): adsb.viljo.se:30006

## Variables

See `defaults/main.yml` for all configuration options.

Key variables:
- `adsb_pi_feeder_ip`: Raspberry Pi Beast server IP
- `use_adsbhub_splitter`: Route ADSBHub through NATS relay Y-splitter
- `api2sbs_server`: Target for api2sbs output (proxy or direct to readsb)

## Dependencies

- LXC container 200 with Docker installed
- Traefik for HTTPS routing
- `adsb_nats_relay` role for Y-splitter and proxy modes
