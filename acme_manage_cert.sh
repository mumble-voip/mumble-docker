#!/bin/bash

set -e

log()
{
	echo "[mumble-cert-manager] $*"
}

# ACME_LEGO_CMD is documented as an alias for ACME_LEGO_ARGS (and is what
# entrypoint.sh historically checked). Accept either so cert management and
# Mumble startup stay in sync.
if [[ -z "$ACME_LEGO_ARGS" && -n "$ACME_LEGO_CMD" ]]; then
	ACME_LEGO_ARGS="$ACME_LEGO_CMD"
fi

if [[ -z "$ACME_DOMAIN" && -z "$ACME_LEGO_ARGS" ]]; then
	log "No automatic certificate management configured. Goodbye."
	sleep infinity # We just let the script hang forever so that supervisord does not put it in a restart loop
fi

LEGO_DIR="/etc/acme"
CERT_DIR="/data/acme"
mkdir -p "$CERT_DIR"

if [[ ! -d "$LEGO_DIR" ]]; then
	>&2 log "[ERROR] '$LEGO_DIR' does not exist. Did you forget to mount a volume?"
	exit 1
fi

# Build a lego command if the user did not provide one
if [[ -n "$ACME_LEGO_ARGS" ]]; then
	# Word-split the user-supplied flag string into an argv array. Without this,
	# `lego run "${LEGO_ARGS[@]}"` would pass the entire string as one argument.
	# shellcheck disable=SC2206
	LEGO_ARGS=($ACME_LEGO_ARGS)
else
	SERVER="${ACME_SERVER:-https://acme-v02.api.letsencrypt.org/directory}"
	DOMAIN="${ACME_DOMAIN}"
	ACCOUNT_MAIL="${ACME_ACCOUNT_MAIL}"
	if [[ -z "$ACCOUNT_MAIL" ]]; then
		>&2 log "[ERROR] Variable ACME_ACCOUNT_MAIL is undefined"
		exit 1
	fi
	LEGO_ARGS=(--email "$ACCOUNT_MAIL" --domains "$DOMAIN" --server "$SERVER" --path "$LEGO_DIR" --accept-tos)

	if [[ -n "$ACME_HTTP" ]]; then
		LEGO_ARGS+=(--http)
	elif [[ -n "$ACME_DNS" ]]; then
		LEGO_ARGS+=(--dns "$ACME_DNS")
		if [[ -n "$ACME_DNS_RESOLVERS" ]]; then
			IFS=';' read -ra resolvers <<< "$ACME_DNS_RESOLVERS"
			for resolver in "${resolvers[@]}"; do
				LEGO_ARGS+=(--dns.resolvers "$resolver")
			done
		fi
	else
		# TODO: TLS-ALPN challenge
		>&2 log "[ERROR] No ACME method configured. Set ACME_HTTP for HTTP-01 challenge or set ACME_DNS to one of the providers listed here: https://go-acme.github.io/lego/dns/index.html"
		exit 1
	fi
fi

log "Mumble startup might be delayed on the initial certificate request"

# Renewal loop
while true; do
	log "Trying to request/renew the TLS certificate"
	lego run "${LEGO_ARGS[@]}" --deploy-hook acme_install_cert

	log "Sleeping 12h before renewal check..."
	sleep $((60 * 60 * 12))
done
