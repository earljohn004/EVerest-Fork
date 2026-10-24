#!/usr/bin/env bash
# Drive the EVerest SIL from the macOS host without VS Code. See README.md.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DEVRD="$REPO/applications/devrd/devrd"
NODERED=http://localhost:1880
DEFAULT_FLOW=config/nodered/config-sil-flow.json
DEFAULT_RUN=run-sil-ocpp.sh

container() {
    local c
    c=$(docker ps -q --filter name=devcontainer-devcontainer-1 | head -1)
    [ -n "$c" ] || { echo "✖ devcontainer not running — run: $0 start" >&2; exit 1; }
    echo "$c"
}

# devrd's own `flow` command uses GNU `sed -i`, which fails on macOS; this is the same steps, portable.
deploy_flow() {
    local flow="${1:-$DEFAULT_FLOW}" tmp
    [ -f "$REPO/$flow" ] || { echo "✖ flow not found: $flow" >&2; exit 1; }
    for _ in $(seq 60); do curl -sf -o /dev/null "$NODERED/flows" && break; sleep 1; done
    tmp=$(mktemp)
    sed 's/"broker": "localhost"/"broker": "mqtt-server"/g' "$REPO/$flow" > "$tmp"
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$NODERED/flows" \
        -H 'Content-Type: application/json' -d @"$tmp")
    rm -f "$tmp"
    case $code in 200|204) echo "✔ Node-RED flow: $flow → $NODERED/ui" ;;
                  *) echo "✖ flow deploy failed (HTTP $code)" >&2; exit 1 ;; esac
}

case "${1:-help}" in
    start)
        # devrd needs SSH keys loaded only when it has to generate .env.
        [ -s "$REPO/.devcontainer/.env" ] || ssh-add -l >/dev/null 2>&1 \
            || { echo "✖ no SSH key in agent — run: ssh-add --apple-use-keychain ~/.ssh/id_ed25519" >&2; exit 1; }
        (cd "$REPO" && "$DEVRD" start)
        deploy_flow "${2:-}"
        open "$NODERED/ui" 2>/dev/null || true
        ;;
    run)
        # Foreground with a TTY so Ctrl+C stops the manager and all its modules.
        case "${2:-powerfill}" in
            powerfill) docker exec -it "$(container)" bash -lc "cd /workspace && ./build/run-scripts/$DEFAULT_RUN" ;;
            sargsrank)
                # Same scenario as run-sil-ocpp.sh, with the OCPP charge-point config swapped.
                docker exec -it "$(container)" bash -lc "
                    sed 's|/workspace/config/ocpp-powerfill.json|/workspace/config/ocpp-relay.json|' \
                        /workspace/config/config-sil-ocpp.yaml > /tmp/config-sil-ocpp-relay.yaml
                    cd /workspace && LD_LIBRARY_PATH=/workspace/build/dist/lib:\$LD_LIBRARY_PATH \
                        /workspace/build/dist/bin/manager --prefix /workspace/build/dist --conf /tmp/config-sil-ocpp-relay.yaml"
                ;;
            *) docker exec -it "$(container)" bash -lc "cd /workspace && ./build/run-scripts/$2" ;;
        esac
        ;;
    flow)  deploy_flow "${2:-}" ;;
    kill)  docker exec "$(container)" pkill -f /workspace/build/dist && echo "✔ manager stopped" || echo "nothing running" ;;
    shell) docker exec -it "$(container)" bash -l ;;
    logs)  docker exec "$(container)" bash -c 'ls -t /tmp/everest_ocpp_logs/*.html | head -5' ;;
    stop)
        docker exec "$(container)" pkill -f /workspace/build/dist 2>/dev/null || true
        (cd "$REPO" && "$DEVRD" stop)
        ;;
    *)
        cat <<EOF
Usage: $0 <command> [arg]
  start [flow]     start containers, load Node-RED flow (default: $DEFAULT_FLOW), open UI
  run [target]     run in the foreground: powerfill (default) | sargsrank | a build/run-scripts/ script
  flow [flow]      (re)load a Node-RED flow
  kill             stop a running manager
  shell            shell inside the devcontainer
  logs             list latest OCPP message logs
  stop             stop manager and all containers
EOF
        ;;
esac
