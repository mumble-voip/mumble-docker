#!/usr/bin/env bash
set -e

readonly DATA_DIR="/data"
readonly BARE_BONES_CONFIG_FILE="/etc/mumble/bare_config.ini"
readonly CONFIG_FILE="${DATA_DIR}/mumble_server_config.ini"

declare -a server_invocation=("${@}")
declare -a existing_config_options
declare -a used_configs

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
	echo -e "# Config file automatically generated from the MUMBLE_CONFIG_* environment variables\n" > "${CONFIG_FILE}"

	# Compile list of configurations that exist in bare bones config

	while read -r line; do
		if [[ "$line" =~ ^(\;|\#)?\ *([a-zA-Z_0-9]+)=.* ]]; then
			existing_config_options+=("${BASH_REMATCH[2]}")
		fi
	done < "$BARE_BONES_CONFIG_FILE"

	# Process settings through variables of format MUMBLE_CONFIG_*

	while IFS='=' read -d '' -r var value; do
		uppercase_variable=${var/MUMBLE_CONFIG_/}
		uppercase_variable_no_underscores="${uppercase_variable//_/}"
		found=false

		for current_config in "${existing_config_options[@]}"; do
			upper_current_config=${current_config^^}

			if [[ "$upper_current_config" = "$uppercase_variable" || "$upper_current_config" = "$uppercase_variable_no_underscores" ]]; then
				set_config "$current_config" "$value"
				found=true
				break
			fi
		done

		if [[ "$found" = "false" ]]; then
			>&2 echo "[ERROR]: Unable to find config corresponding to variable \"$var\""
			exit 1
		fi
	done < <( printenv --null | grep -az MUMBLE_CONFIG_ ) # Feeding it in like this, prevents the creation of a subshell for the while-loop

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

server_invocation+=( "-ini" "${CONFIG_FILE}")

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
