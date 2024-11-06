#!/usr/bin/env bash
set -e

readonly DATA_DIR="/data"
readonly BARE_BONES_CONFIG_FILE="/etc/mumble/bare_config.ini"
readonly CONFIG_REGEX="^(\;|\#)?\ *([a-zA-Z_0-9]+)=.*"
CONFIG_FILE="${DATA_DIR}/mumble_server_config.ini"
MUMBLE_UID=${MUMBLE_UID:-10000}
MUMBLE_GID=${MUMBLE_GID:-10000}
MUMBLE_CHOWN=${MUMBLE_CHOWN:-true}

readonly SENSITIVE_CONFIGS=(
	"dbPassword"
	"icesecretread"
	"icesecretwrite"
	"serverpassword"
	"registerpassword"
	"sslPassPhrase"
)

# Compile list of configuration options from the bare-bones config
readarray -t existing_config_options < <(sed -En "s/$CONFIG_REGEX/\2/p" "$BARE_BONES_CONFIG_FILE")

# Grab the original command line that is supposed to start the Mumble server
declare -a server_invocation=("${@}")
declare -a used_configs

normalize_name() {
	local uppercase="${1^^}"
	echo "${uppercase//_/}"
}

# Create an associative array for faster config option lookup
declare -A option_for

for config in "${existing_config_options[@]}"; do
	option_for["$(normalize_name "$config")"]="$config"
done

array_contains() {
	local array_expansion="$1[@]" seeking="$2"
	for element in "${!array_expansion}"; do
		[[ "$element" = "$seeking" ]] && return 0
	done
	return 1
}

set_config() {
	local config_name="$1" config_value="$2" is_default="$3"
	local apply_value=true

	[[ "$is_default" = true ]] && array_contains "used_configs" "$config_name" && \
		apply_value=false # Don't use default value if the user already set one!

	[[ "$apply_value" != true ]] && return 0

	if array_contains "SENSITIVE_CONFIGS" "$config_name"; then
		echo "Setting config \"$config_name\" to: *********"
	else
		echo "Setting config \"$config_name\" to: '$config_value'"
	fi
	used_configs+=("$config_name")

	# Append config to our on-the-fly-built config file
	echo "${config_name}=${config_value}" >> "$CONFIG_FILE"
}

# Drop the user into a shell, if they so wish
if [[ "$1" = "bash" ||  "$1" = "sh" ]]; then
    echo "Dropping into interactive BASH session"
    exec "${@}"
fi

if [[ -f "$MUMBLE_CUSTOM_CONFIG_FILE" ]]; then
	echo "Using manually specified config file at $MUMBLE_CUSTOM_CONFIG_FILE"
	echo "All MUMBLE_CONFIG variables will be ignored"
	CONFIG_FILE="$MUMBLE_CUSTOM_CONFIG_FILE"
else
	# Ensures the config file is empty, starting from a clean slate
	echo -e "# Config file automatically generated from the MUMBLE_CONFIG_* environment variables" > "${CONFIG_FILE}"
	echo -e "# or secrets in /run/secrets/MUMBLE_CONFIG_* files\n" >> "${CONFIG_FILE}"

	# Process settings through variables of format MUMBLE_CONFIG_*

	while IFS='=' read -d '' -r var value; do
		config_option="${option_for[$(normalize_name "$var")]}"

		if [[ -z "$config_option" ]]; then
			if [[ "$MUMBLE_ACCEPT_UNKNOWN_SETTINGS" = true ]]; then
				echo "[WARNING]: Unable to find config corresponding to variable \"$var\". Make sure that it is correctly spelled, using it as-is"
				set_config "$var" "$value"
			else
				>&2 echo "[ERROR]: Unable to find config corresponding to variable \"$var\""
				exit 1
			fi
		else
			set_config "$config_option" "$value"
		fi

	done < <( printenv --null | sed -zn 's/^MUMBLE_CONFIG_//p' )
	# ^ Feeding it in like this, prevents the creation of a subshell for the while-loop

	# Check any docker/podman secrets matching the pattern and set config from there
	while read -r var; do
		config_option="${option_for[$(normalize_name "$var")]}"
		secret_file="/run/secrets/MUMBLE_CONFIG_$var"
		if [[ -z "$config_option" ]]; then
			if [[ "$MUMBLE_ACCEPT_UNKNOWN_SETTINGS" = true ]]; then
				echo "[WARNING]: Unable to find config corresponding to container secret \"$secret_file\". Make sure that it is correctly spelled, using it as-is"
				set_config "$var" "$value"
			else
				>&2 echo "[ERROR]: Unable to find config corresponding to container secret \"$secret_file\""
				exit 1
			fi
		else
			set_config "$config_option" "$(cat $secret_file)"
		fi
	done < <( ls /run/secrets | sed -n 's/^MUMBLE_CONFIG_//p' )

	# Apply default settings if they're missing

	# Compatibilty with old DB filename
	OLD_DB_FILE="${DATA_DIR}/murmur.sqlite"
	if [[ -f "$OLD_DB_FILE" ]]; then
		set_config "database" "$OLD_DB_FILE" true
	else
		set_config "database" "${DATA_DIR}/mumble-server.sqlite" true
	fi

	set_config "ice" "\"tcp -h 127.0.0.1 -p 6502\"" true

	if ! array_contains "used_configs" "welcometextfile"; then
		set_config "welcometext" "\"<br />Welcome to this server, running the official Mumble Docker image.<br />Enjoy your stay!<br />\"" true
	fi

	set_config "port" 64738 true
	set_config "users" 100 true

	{ # Add ICE section
		echo -e "\n[Ice]"
		echo "Ice.Warn.UnknownProperties=1"
		echo "Ice.MessageSizeMax=65536"
	} >> "$CONFIG_FILE"
fi

# Additional environment variables

[[ "$MUMBLE_VERBOSE" = true ]] && server_invocation+=( "-v" )

# Make sure the correct configuration file is used
server_invocation+=( "-ini" "${CONFIG_FILE}")

if [[ -f /run/secrets/MUMBLE_SUPERUSER_PASSWORD ]]; then
	MUMBLE_SUPERUSER_PASSWORD="$(cat /run/secrets/MUMBLE_SUPERUSER_PASSWORD)"
    echo "Read superuser password from container secret"
fi

if [[ -n "${MUMBLE_SUPERUSER_PASSWORD}" ]]; then
	#Variable to change the superuser password
    "${server_invocation[@]}" -supw "$MUMBLE_SUPERUSER_PASSWORD"
    echo "Successfully configured superuser password"
fi

# Show /data permissions, in case the user needs to match the mount point access
echo "Entrypoint running as uid=$(id -u) gid=$(id -g)"
echo "Preparing Mumble server to run as uid=$(MUMBLE_UID) gid=$(MUMBLE_GID)"

if [[ "$MUMBLE_UID" != "0" ]]; then
  groupmod -og "$MUMBLE_GID" mumble
  usermod -ou "$MUMBLE_UID" mumble
  if [[ "$MUMBLE_CHOWN" = true ]]; then
    echo "Changing owner of folder ${DATA_DIR}"
    chown -R mumble:mumble "${DATA_DIR}"
  fi
  exec runuser -u mumble -g mumble -- "$@"
fi

echo "\"${DATA_DIR}\" has the following permissions set:"
echo "  $( stat ${DATA_DIR} --printf='%A, owner: \"%U\" (UID: %u), group: \"%G\" (GID: %g)' )"

echo "Command run to start the service : ${server_invocation[*]}"
echo "Starting..."

if [[ "$MUMBLE_UID" != "0" ]]; then
    exec runuser -u mumble -g mumble -- "${server_invocation[@]}"
else
    exec "${server_invocation[@]}"
fi
