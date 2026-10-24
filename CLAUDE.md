# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

This is [EVerest](https://everest.github.io), a Linux Foundation Energy modular open-source
stack for EV charging stations (charge points). It supports OCPP 1.6, OCPP 2.0.1/2.1,
ISO 15118, and IEC 61851, and modules communicate over MQTT.

**This checkout is used for study and documentation of EV charging with a CSMS connection —
no code changes are expected here.** It has already been built (CMake output lives in
`build/`), and the entry point for working with it is the pre-built `build/run-scripts/`,
not the build system itself. Treat this repo as read-only unless explicitly told otherwise.

**EVerest is the charge point, not the CSMS.** In software-in-the-loop (SIL) mode it
simulates the hardware and the EV, and runs the OCPP *client* talking to an external CSMS
(Central System). See `docs/OCPP-and-EVerest-relationship.md` for the full breakdown of this
relationship, how to point EVerest at a different CSMS, and where to inspect OCPP traffic —
it's the most relevant doc in this repo for CSMS-integration work.

## Running the simulation (SIL)

1. Start the MQTT broker (mosquitto) that all EVerest modules use to communicate:
   ```
   docker network create --driver bridge --ipv6 --subnet fd00::/80 infranet_network --attachable
   docker run -d --name mqtt-server --network infranet_network -p 1883:1883 -p 9001:9001 ghcr.io/everest/containers/mosquitto:docker-images-v0.1.0
   ```
2. From `build/run-scripts/`, run one of the pre-generated launcher scripts. Each one starts
   the `manager` binary with `--prefix build/dist --conf config/<config>.yaml`. The scripts
   as generated hardcode `/workspace/...` paths (the devcontainer mount point) — run them
   inside the devcontainer, or substitute `/workspace` for this repo's actual path.

   | Goal | Run script | Config |
   |------|-----------|--------|
   | Charging SIL only, no OCPP | `run-sil.sh` | `config/config-sil.yaml` |
   | OCPP 1.6 SIL | `run-sil-ocpp.sh` (also `-pnc` variant) | `config/config-sil-ocpp*.yaml` |
   | OCPP 2.x SIL | `run-sil-ocpp201.sh` (also `-pnc` variant) | `config/config-sil-ocpp201.yaml` (two EVSEs by default) |

3. In a second terminal, run `run-scripts/nodered-sil.sh` and open `http://localhost:1880/ui`
   for a simple GUI to drive a simulated session (`CAR PLUGIN`, `PAUSE`, `RESUME`, etc.).

## This checkout's CSMS config

`config/ocpp-powerfill.json` is a custom OCPP 1.6 charge-point config, wired in via
`config/config-sil-ocpp.yaml`'s `ocpp` module (`config_module.ChargePointConfigPath`). Key
fields to know when reasoning about or changing the CSMS connection:

- `Internal.CentralSystemURI`, `Internal.ChargePointId` — where/who this charge point connects as.
- `Security.SecurityProfile`, `Security.AuthorizationKey` — OCPP security profile/auth.
- `Core.*` — standard OCPP 1.6 Core profile configuration keys (heartbeat, meter values, etc.).

To point OCPP 1.6 at a different CSMS, edit this JSON directly (`CentralSystemURI`,
`ChargePointId`, `SecurityProfile`, `AuthorizationKey`); for OCPP 2.x, the equivalent lives in
the device-model `NetworkConfiguration` slots instead of a flat JSON file — see
`docs/OCPP-and-EVerest-relationship.md`.

OCPP message logs land at `/tmp/everest_ocpp_logs` (configurable via the `OCPP` module's
`MessageLogPath`, see `modules/EVSE/OCPP/manifest.yaml`). Session logs are configured
per-EVSE in the config YAML (e.g. `evse_manager_*.config_module.session_logging_path`).

## Architecture: modules, interfaces, types

EVerest wires together independent module processes at runtime, connected via MQTT. Three
kinds of YAML files define this:

- **`modules/<Category>/<ModuleName>/manifest.yaml`** — one per module. Declares the
  module's `config` keys, the interfaces it `provides` (implements) and `requires`
  (depends on), each with `min_connections`/`max_connections`.
- **`interfaces/*.yaml`** — the contract a module can implement: `vars` (data it publishes)
  and `cmds` (commands other modules can call on it).
- **`types/*.yaml`** — shared struct definitions referenced from interfaces via `$ref`.
- **A scenario config, `config/config-sil*.yaml`** — the actual wiring diagram: it
  instantiates modules under `active_modules`, sets their `config_module` values, and links
  them together under `connections` (by `module_id` + `implementation_id`). Read the
  relevant `config-sil-*.yaml` to understand any given scenario's module graph — e.g.
  `config-sil-ocpp.yaml` shows `ocpp` connected to `evse_manager_1/2`, `auth`, `system`,
  `evse_security`, and `display_message`.

Modules are grouped by domain under `modules/`:

- `EVSE/` — charge-point side: `EvseManager` (a charging port), `OCPP` (1.6J) and `OCPP201`
  (2.0.1/2.1), `EvseV2G`/`Iso15118InternetVas` (ISO 15118 HLC), `Auth`, `EvseSecurity`.
- `EV/` — the simulated vehicle side (`EvManager`, `EvSlac`, `PyEvJosev`).
- `Simulation/` — hardware simulators (`YetiSimulator`, `SlacSimulator`, `DCSupplySimulator`, etc.).
- `EnergyManagement/` — `EnergyManager`, `EnergyNode` (energy limits/tree).
- `API/` — external-facing API modules (`API`, `EvAPI`, `RpcApi`).
- `HardwareDrivers/` — real hardware BSPs (power meters, isolation monitors, NFC, payment).
- `Misc/` — `System`, `ErrorHistory`, `PersistentStore`, `Store`, etc.
- `Testing/` — dummy token providers/validators for driving scenarios without real hardware.
- `BringUp/` — single-module bring-up harnesses for hardware integration.
- `framework/` — the core EVerest runtime/manager and language bindings (C++/Python/Rust).
