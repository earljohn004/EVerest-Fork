# Local SIL runbook (macOS, no VS Code)

Run the EVerest SIL with the Node-RED UI against the Powerfill CSMS, all from a terminal.

## Prerequisites

- Docker Desktop running.
- SSH key in the agent. Required by `devrd` the first time it generates
  `.devcontainer/.env`. The macOS agent is emptied on reboot:
  ```
  ssh-add --apple-use-keychain ~/.ssh/id_ed25519
  ```
  This is also what breaks VS Code "Reopen in Container" (`SSH agent is not running or no keys are loaded`).
- `build/` already built (it is; `build/dist/bin/manager` is aarch64).

## Quick start

Terminal 1 — containers + UI:
```
./local-sil/sil.sh start
```
Starts mqtt-server, nodered, steve, ocpp-db, mqtt-explorer and the devcontainer, loads
`config/nodered/config-sil-flow.json` into Node-RED and opens http://localhost:1880/ui.

Terminal 2 — the charge point (foreground, Ctrl+C to stop):
```
./local-sil/sil.sh run                  # run-sil-ocpp.sh → Powerfill (config/ocpp-powerfill.json)
./local-sil/sil.sh run sargsrank        # same scenario → ocpp.sargsrank.com (config/ocpp-relay.json)
./local-sil/sil.sh run run-sil.sh       # charging only, no OCPP
./local-sil/sil.sh run run-sil-ocpp201.sh
```

Then in the UI: **CAR PLUGIN** → session starts; **STOP & UNPLUG** ends it.

Done for the day:
```
./local-sil/sil.sh stop
```

## Commands

| Command | What it does |
|---|---|
| `start [flow]` | `devrd start`, deploy Node-RED flow, open UI |
| `run [script]` | run a `build/run-scripts/` script in the devcontainer, foreground |
| `flow [flow]` | (re)load a Node-RED flow, e.g. `config/nodered/config-sil-two-evse-flow.json` |
| `kill` | stop a manager that is still running (e.g. one started with `&`) |
| `shell` | bash inside the devcontainer |
| `logs` | list latest OCPP message logs (`/tmp/everest_ocpp_logs` in the container) |
| `stop` | kill manager, stop all containers |

Flows available: `./applications/devrd/devrd flows`. Note `devrd flow` itself fails on macOS
(GNU `sed -i`); use `sil.sh flow` instead.

## URLs

| Service | URL |
|---|---|
| Node-RED UI | http://localhost:1880/ui |
| Node-RED editor | http://localhost:1880 |
| MQTT Explorer | http://localhost:4000 |
| SteVe (local CSMS) | http://localhost:8180 |

## Troubleshooting

- **UI shows nothing / no buttons** — flow not loaded: `./local-sil/sil.sh flow`.
- **Buttons do nothing** — no manager running: `./local-sil/sil.sh run`.
- **Manager started in background by mistake** — `fg` then Ctrl+C, or `./local-sil/sil.sh kill`.
- **CSMS connection** — target is set in `config/ocpp-powerfill.json` (powerfill) or
  `config/ocpp-relay.json` (sargsrank)
  (`Internal.CentralSystemURI`, `ChargePointId`, `Security.*`); see
  `docs/OCPP-and-EVerest-relationship.md`.
