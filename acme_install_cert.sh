#!/bin/bash

set -e

log()
{
	echo "[mumble-cert-manager] $*"
}

MUMBLE_CERT_DIR=/data/acme
PUID=${PUID:-10000}
PGID=${PGID:-10000}

log "Installing new certificate to $MUMBLE_CERT_DIR"
install --owner="$PUID" --group="$PGID" --mode=0644 "$LEGO_CERT_PATH" "$MUMBLE_CERT_DIR/mumble.crt"
install --owner="$PUID" --group "$PGID" --mode=0640 "$LEGO_CERT_KEY_PATH" "$MUMBLE_CERT_DIR/mumble.key"

mumble_pid="$(pidof mumble-server || true)"
if [[ -n "$mumble_pid" ]]; then
	log "Signaling mumble to reload the certificate"
	kill -USR1 "$mumble_pid"
else
	log "Mumble does not seem to be running (yet), so no certificate reload signal is sent"
fi
