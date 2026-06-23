# OCPP and EVerest relationship

Reference note for building or testing a **CSMS** (Charging Station Management System) against EVerest **software-in-the-loop (SIL)**.

## Short answer

EVerest is the **charging station (charge point) stack**, not a CSMS. In SIL it simulates hardware and an EV and runs the **OCPP client** on the station side. **Your CSMS** is the central system; EVerest connects to it over OCPP so you can develop features, drive sessions, and inspect **transactions and message flows**.

## Roles

| Component | Role in your setup |
|-----------|-------------------|
| **Your CSMS** | Central system: auth, sessions, billing, remote control, fleet ops |
| **EVerest SIL** | Simulated charger(s) + simulated EV + ISO 15118 / energy / auth |
| **OCPP modules** (`OCPP` 1.6J, `OCPP201` 2.0.1/2.1) | Station-side OCPP; talks **to** your CSMS |

The [Plug&Charge tutorial](https://everest.github.io/latest/tutorials/plug-and-charge.html) describes the same split: EVerest is the SECC/charger stack; the CSMS is **external** (e.g. [EVerest/ocpp-csms](https://github.com/EVerest/ocpp-csms)).

## Does EVerest act as a simulator for CSMS work?

**Yes — as a charge-point simulator, not as a CSMS simulator.**

What SIL provides:

- **Physical / session layer (simulated):** YetiSimulator, EvManager car sim, SLAC, ISO 15118, powermeter, etc.
- **OCPP layer:** libocpp-based **charge point** wired into EvseManager, Auth, energy, and related modules.
- **Driving sessions:** Node-RED UI (car plugin, profiles) and/or token/auth flows in OCPP-enabled configs — same idea as basic SIL, with OCPP enabled.

### Typical entry points in this repo

| Goal | Run script | EVerest config |
|------|------------|----------------|
| Charging SIL only (no OCPP) | `./run-scripts/run-sil.sh` | `config/config-sil.yaml` |
| OCPP 1.6 SIL | `./run-scripts/run-sil-ocpp.sh`, `run-sil-ocpp-pnc.sh`, … | `config/config-sil-ocpp*.yaml` |
| OCPP 2.x SIL | `./run-scripts/run-sil-ocpp201.sh`, `run-sil-ocpp201-pnc.sh`, … | `config/config-sil-ocpp201.yaml` (default includes **two EVSEs**) |

Official walkthrough: [OCPP 2.0.1 and 2.1 in EVerest](https://everest.github.io/latest/tutorials/ocpp2.html) — includes running SIL against the reference CSMS at `localhost:9000`.

## Inspecting OCPP transactions and charging

### On the EVerest (charge point) side

- **OCPP message logs** (several formats): `/tmp/everest_ocpp_logs` (see OCPP 2.x tutorial).
- **Module / session logs:** EVerest console; session logging paths depend on config (e.g. `/tmp`, `/tmp/everest-logs`).
- **MQTT** (e.g. MQTT Explorer in the devcontainer): useful for **internal** module traffic; **not** a full substitute for OCPP transaction inspection.

### On the CSMS side (your product)

- Persist and display **StartTransaction** / **TransactionEvent**, **MeterValues**, **StopTransaction**, id tags, etc.
- EVerest is the **client** emitting those messages when a simulated session runs.

### Reference CSMS in this ecosystem (for comparison)

- **[SteVe](https://github.com/steve-community/steve)** — used in the devcontainer OCPP 1.6 example. From **inside** the devcontainer, point the charge point at `steve:8180`, not `127.0.0.1:8180`. See [SIL with OCPP (devcontainer)](https://everest.github.io/latest/how-to-guides/devcontainer-usage/index.html).
- **[EVerest/ocpp-csms](https://github.com/EVerest/ocpp-csms)** — minimal CSMS for OCPP 2.x; default **`localhost:9000`**, aligned with SIL OCPP 2.x configs.

libocpp documents CSMS compatibility testing including SteVe in [`lib/everest/ocpp/README.md`](../lib/everest/ocpp/README.md).

## Pointing EVerest at your own CSMS

### OCPP 2.x

Configure device model **NetworkConfiguration** slots: `OcppCsmsUrl`, `SecurityProfile`, identity and basic auth (`SecurityCtrlr`, per-slot overrides). Details: [Connect to a different CSMS](https://everest.github.io/latest/tutorials/ocpp2.html#connect-to-a-different-csms) (device model under `lib/everest/ocpp/config/v2/component_config/`).

### OCPP 1.6

Edit the OCPP JSON config: `CentralSystemURI`, `ChargePointId`, `SecurityProfile`, `AuthorizationKey`. Path is set via `ChargePointConfigPath` on the OCPP module in the EVerest YAML. See [OCPP 1.6 — connect to a different CSMS](https://everest.github.io/latest/tutorials/ocpp16.html).

### Typical development loop

1. Run your CSMS (WebSocket endpoint reachable from where EVerest runs — mind devcontainer vs host networking).
2. Start e.g. `./run-scripts/run-sil-ocpp201.sh` and the matching Node-RED flow.
3. Start a session from the UI or auth/token path.
4. Correlate **CSMS DB/UI** with **`/tmp/everest_ocpp_logs`**.

## What EVerest does not replace

- **CPO back-office** (roaming, invoicing, tariffs, OCPI, etc.) — that is your CSMS.
- **Many unrelated charge points** — unless you run multiple EVerest instances or use multi-EVSE configs against one CSMS.
- **OCPP without OCPP configs** — `run-sil.sh` alone is charging SIL only; use `run-sil-ocpp*` and a reachable CSMS for OCPP transactions.

## Suggested path if you are building your own CSMS

1. Implement OCPP 2.0.1 (or 1.6J if required) central system WebSocket server + persistence.
2. Use **EVerest SIL + OCPP201** (or OCPP 1.6) as a capable **simulated charge point** under test.
3. Sanity-check with **ocpp-csms** or **SteVe**, then point `OcppCsmsUrl` / `CentralSystemURI` at your service.
4. Debug with **`/tmp/everest_ocpp_logs`** plus your CSMS logs; consider OCA OCTT later for formal interoperability testing.

## Related documentation

- [Get started in Software](https://everest.github.io/latest/how-to-guides/getting-started/get-started-sw.html)
- [OCPP 2.x tutorial](https://everest.github.io/latest/tutorials/ocpp2.html)
- [OCPP 1.6 tutorial](https://everest.github.io/latest/tutorials/ocpp16.html)
- [Plug&Charge with EVerest SIL](https://everest.github.io/latest/tutorials/plug-and-charge.html)
