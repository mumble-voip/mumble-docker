#!/usr/bin/env bash
set -e

readonly DATA_DIR="/data"
readonly BARE_BONES_CONFIG_FILE="/etc/mumble/bare_config.ini"
readonly CONFIG_FILE="${DATA_DIR}/mumble_server_config.ini"
readonly CONFIG_REGEX="^(\;|\#)?\ *([a-zA-Z_0-9]+)=.*"

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

	echo "Setting config \"$config_name\" to: '$config_value'"
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
	echo -e "# Config file automatically generated from the MUMBLE_CONFIG_* environment variables\n" > "${CONFIG_FILE}"

	# Process settings through variables of format MUMBLE_CONFIG_*

	while IFS='=' read -d '' -r var value; do
		config_option="${option_for[$(normalize_name "$var")]}"

		if [[ -z "$config_option" ]]; then
			>&2 echo "[ERROR]: Unable to find config corresponding to variable \"$var\""
			exit 1
		fi

		set_config "$config_option" "$value"
	done < <( printenv --null | sed -zn 's/^MUMBLE_CONFIG_//p' )
	# ^ Feeding it in like this, prevents the creation of a subshell for the while-loop

	# Apply default settings if they're missing

	set_config "database" "${DATA_DIR}/murmur.sqlite" true
	set_config "ice" "\"tcp -h 127.0.0.1 -p 6502\"" true
	set_config "welcometext" "\"<br />Welcome to this server, running the official Mumble Docker image.<br />Enjoy your stay!<br />\"" true
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

# Variable to change the superuser password
if [[ -n "${MUMBLE_SUPERUSER_PASSWORD}" ]]; then
    "${server_invocation[@]}" -supw "$MUMBLE_SUPERUSER_PASSWORD"
    echo "Successfully configured superuser password"
fi

# Show /data permissions, in case the user needs to match the mount point access
echo "Running Mumble server as uid=$(id -u) gid=$(id -g)"
echo "\"${DATA_DIR}\" has the following permissions set:"
echo "  $( stat ${DATA_DIR} --printf='%A, owner: \"%U\" (UID: %u), group: \"%G\" (GID: %g)' )"

echo "Command run to start the service : ${server_invocation[*]}"
echo "Starting..."

exec "${server_invocation[@]}"
