# Run the EVerest SIL permanently on an x86_64 VPS

## Context
The user wants the stack from `local-sil/sil.sh` (EVerest OCPP 1.6 SIL + MQTT + Node-RED, talking to the
external Powerfill CSMS) running permanently on an **x86_64** VPS.

**Exporting the current containers with `docker save` won't work:**
- `everest-core_devcontainer-devcontainer` only holds the toolchain. EVerest itself lives in the bind-mounted
  repo (`build/dist`), so it isn't part of any image.
- `build/dist/bin/manager` is an **ARM64** binary (built on the Mac), so it can't run on x86_64.
- The devcontainer also needs dev-only pieces: the SSH agent socket, the docker-proxy, and `sleep infinity` + `docker exec`.
- mosquitto and Node-RED are public images and are simply pulled on the VPS.

**Approach:** reuse the existing upstream recipe `applications/utils/docker/everest-docker-image/`
(Dockerfile + build.sh + docker-compose.yml). It builds a slim runtime image with EVerest installed at
`/opt/everest`. **The VPS has only 4 GB RAM, which is too little to compile EVerest, so the VPS only pulls and runs the image.**
The amd64 image is built by a **GitHub Actions workflow in the fork** (`earljohn004/EVerest-Fork`, branch
`everest-study`) and pushed to GHCR. Emulating amd64 on the Mac for a C++ build this size would take many hours.
The runtime footprint (manager + mosquitto + Node-RED) fits comfortably in 4 GB. The three services run with
`restart: unless-stopped`. Personal changes are configs only (commit 7fc3403b + untracked
`ocpp-powerfill.json`), so they're mounted at runtime and the upstream code builds unmodified.

## Files to create
0. `.github/workflows/everest-image.yml` (manual `workflow_dispatch`): `docker/build-push-action` builds
   `applications/utils/docker/everest-docker-image/Dockerfile` for `linux/amd64`, with build-args
   `REPO=https://github.com/earljohn004/EVerest-Fork.git`, `BRANCH=everest-study`,
   `ADDITIONAL_CMAKE_PARAMETERS=-DEVEREST_BUILD_ALL_MODULES=ON`, and the configs copied into the context. It pushes
   `ghcr.io/earljohn004/everest-sil:latest`. If the fork is private, the runner has only 7 GB RAM, so add a swapfile
   step first.

The files below live in `local-sil/vps/` and get scp'd to the VPS.

1. `local-sil/vps/docker-compose.yml`, based on the upstream `everest-docker-image/docker-compose.yml`:
   - `mqtt-server`: `ghcr.io/everest/containers/mosquitto:docker-images-v0.1.0` (the image already used locally;
     upstream's compose points at a `../mosquitto/mosquitto.conf` that doesn't exist). No public port.
   - `nodered`: `ghcr.io/everest/everest-dev-environment/nodered:docker-images-v0.1.0` (amd64, the same image as
     `build/run-scripts/nodered-sil.sh`). Mount the flow as `/data/flows.json`. Port `127.0.0.1:1880:1880`.
   - `everest`: `ghcr.io/earljohn004/everest-sil:latest`, `MQTT_SERVER_ADDRESS=mqtt-server`, IPv6 sysctl (as upstream). Mount
     `config.yaml` → `/opt/everest/config/config.yaml`, `ocpp-powerfill.json` → `/opt/everest/config/ocpp-config.json`,
     and a named volume for logs and the persistent store.
   - Put `restart: unless-stopped` on all three services.
2. `local-sil/vps/config.yaml`: a copy of `config/config-sil-ocpp.yaml` with
   `ChargePointConfigPath: /opt/everest/config/ocpp-config.json` (line 161). Optionally move `/tmp` logs to the volume.
3. `local-sil/vps/flows.json`: `config/nodered/config-sil-flow.json` with `"broker": "localhost"` →
   `"broker": "mqtt-server"`. This is the same sed `sil.sh:24` applies.
4. `local-sil/vps/README.md`: the VPS steps below.

Reused as-is: the upstream `Dockerfile` and `build.sh`. Nothing in the repo proper is modified.

## Security (not skipped)
- Node-RED has no auth, and anyone reaching it can plug in or stop sessions. Bind it to `127.0.0.1` and reach it via
  `ssh -L 1880:localhost:1880 vps`.
- MQTT is not published at all, so it's reachable only on the compose network.
- `ocpp-powerfill.json` contains `AuthorizationKey`. Copy it with `scp`, never commit it, and `chmod 600` it on the VPS.

## Sequencing
This is a single causal chain on one machine. Nothing is worth parallelizing or delegating to agents. The local files
(steps 0–4) are written inline.

In order:
1. Commit the workflow and push `everest-study`. With the user's OK, run the workflow from the Actions tab.
   **Gate:** the job is green and the image is in GHCR. The upstream Dockerfile may be stale (e.g. its extra
   `EVerest/EVerest.git` clone): fix it in the workflow or Dockerfile and rerun. The VPS is never used for the build.
2. On the VPS: install Docker + compose, and `docker login ghcr.io` (only needed if the package is private).
3. `scp local-sil/vps/* config/ocpp-powerfill.json vps:~/everest-sil/`, then `docker compose up -d`.
4. **Gate:** `docker compose logs everest` shows the OCPP websocket connected to Powerfill, and a BootNotification is accepted.

## Verification
- `docker compose ps`: all three services are up. Run `sudo reboot`, and they come back on their own.
- Over the SSH tunnel, `http://localhost:1880/ui` loads. Click CAR PLUGIN and check that the session appears in the Powerfill CSMS.
- `docker compose exec everest ls /tmp/everest_ocpp_logs`: the OCPP message logs exist.
