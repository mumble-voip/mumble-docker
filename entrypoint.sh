#!/usr/bin/env bash
set -e

DATA_DIR="/data"
BARE_BONES_CONFIG_FILE="/etc/mumble/bare_config.ini"
CONFIG_FILE="${DATA_DIR}/mumble_server_config.ini"

# Grab the original command line that is supposed to start the Mumble server
server_invocation=( "${@}" )

array_contains () { 
	local array="$1[@]"
	local seeking=$2
	local contained=false
	for element in "${!array}"; do
		if [[ $element == "$seeking" ]]; then
			contained=true
			break
		fi
	done

	echo "$contained"
}

set_config() {
	local config_name="$1"
	local config_value="$2"
	local is_default="$3"
	local apply_value=true

	# Don't use default value if the user already set one
	if [ "$is_default" = "true" ]; then
		contained=$( array_contains used_configs "$config_name" )
		if [[ "$contained" = "true" ]]; then
			apply_value=false
		fi
	fi
    
    if [ "$apply_value" = "true" ]; then
        echo "Setting config \"$config_name\" to: '$config_value'"
        used_configs+=("$config_name")
        
        # Append config to our on-the-fly-built config file
        echo "${config_name}=${config_value}" >> "$CONFIG_FILE"
    fi
}
    
# Drop the user into a shell, if they so wish
if [ "$1" = "bash" ] || [ "$1" = "sh" ]; then
    echo "Dropping into interactive BASH session"
    exec "${@}"
fi

if [ -f "$MUMBLE_CUSTOM_CONFIG_FILE" ]; then
	# Just use the config file specified by the user and don't bother assembling our own
	echo "Using manually specified config file at $MUMBLE_CUSTOM_CONFIG_FILE"
	echo "All MUMBLE_CONFIG variables will be ignored"
	CONFIG_FILE="$MUMBLE_CUSTOM_CONFIG_FILE"
else
	# As a first step, we ensure that the config file is empty, so we can always start from a clean slate
	echo -e "# Config file automatically generated from the MUMBLE_CONFIG_* environment variables\n" > "${CONFIG_FILE}"

	used_configs=()
	existing_config_options=()
    
	####
	# Check what kind of configurations there exist in the bare bones config file
	####
	while read -r line; do
		if [[ "$line" =~ ^(\;|\#)?\ *([a-zA-Z_0-9]+)=.* ]]; then
			existing_config_options+=("${BASH_REMATCH[2]}")
		fi
	done < "$BARE_BONES_CONFIG_FILE"
	####
	# Process settings following environments variables starting with "MUMBLE_CONFIG_"
	# Iterate over all environment variable key, value pairs and check if they match our naming scheme
	####
	while IFS='=' read -d '' -r var value; do
		uppercase_variable=${var/MUMBLE_CONFIG_/}

		# Remove underscores (to ensure that it doesn't matter whether the user
		# uses e.g. MUMBLE_CONFIG_DB_BLA or MUMBLE_CONFIG_DBBLA)
		uppercase_variable_no_underscores="${uppercase_variable//_/}"
		found=false

		for current_config in "${existing_config_options[@]}"; do
			# convert to uppercase
			upper_current_config=${current_config^^}

			if [ "$upper_current_config" = "$uppercase_variable" ] || [ "$upper_current_config" = "$uppercase_variable_no_underscores" ]; then
				set_config "$current_config" "$value"
				found=true
				break
			fi
		done

		if [ "$found" = "false" ]; then
			>&2 echo "[ERROR]: Unable to find config corresponding to variable \"$var\""
			exit 1
		fi
	done < <( printenv --null | grep -az MUMBLE_CONFIG_ ) # Feeding it in like this, prevents the creation of a subshell for the while-loop

	####
	# Default settings (will apply only, if user hasn't specified the respective config options themselves)
	####
	set_config "database" "${DATA_DIR}/murmur.sqlite" true
	set_config "ice" "\"tcp -h 127.0.0.1 -p 6502\"" true
	set_config "welcometext" "\"<br />Welcome to this server, running the official Mumble Docker image.<br />Enjoy your stay!<br />\"" true
	set_config "port" 64738 true
	set_config "users" 100 true

	# Add ICE section
	echo -e "\n[Ice]" >> "$CONFIG_FILE"
	echo "Ice.Warn.UnknownProperties=1" >> "$CONFIG_FILE"
	echo "Ice.MessageSizeMax=65536" >> "$CONFIG_FILE"
fi

####
# Additionnal environement variables
####
if [ -n "$MUMBLE_VERBOSE" ] && [ "$MUMBLE_VERBOSE" = true ]; then
    server_invocation+=( "-v" )
fi

# Make sure the correct config file will be used
server_invocation+=( "-ini" "${CONFIG_FILE}")

####
# Variable to change the superuser password
####
if [ -n "${MUMBLE_SUPERUSER_PASSWORD}" ]; then
    "${server_invocation[@]}" -supw "$MUMBLE_SUPERUSER_PASSWORD"
    echo "Successfully configured superuser password"
fi

# Show /data permissions, in case the user needs to match the mount point access
echo "Running Mumble server as uid=$(id -u) gid=$(id -g)"
echo "\"${DATA_DIR}\" has the following permissions set:"
echo "  $( stat ${DATA_DIR} --printf='%A, owner: \"%U\" (UID: %u), group: \"%G\" (GID: %g)' )"

echo "Command run to start the service : ${server_invocation[@]}"
echo "Starting..."

exec "${server_invocation[@]}"
