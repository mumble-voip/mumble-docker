#!/usr/bin/env bash

# Determines the Mumble build number and prints it to stdout (all diagnostics go to stderr).
#
# Usage: resolve_build_number.sh [path-to-mumble-repo]   (defaults to the current directory)
#
# The number provided by the user (MUMBLE_BUILD_NUMBER or, failing that, the build component of a
# MUMBLE_VERSION of the form [v]major.minor.build[-suffix]) is always cross-checked against the Mumble
# build number servers:
# - If the servers can't be reached, the provided number is used verbatim (0 if none was provided).
# - If the provided number is non-zero and differs from the fetched one, this is an error.
# - Otherwise, the fetched number is used.

set -e

REPO_DIR="$(realpath "${1:-.}")"
BUILD_NUMBER_SCRIPT="$REPO_DIR/scripts/mumble-build-number.py"
VERSION_SCRIPT="$REPO_DIR/scripts/mumble-version.py"

provided=""
if [[ -n "$MUMBLE_BUILD_NUMBER" ]]; then
	provided="$MUMBLE_BUILD_NUMBER"
	echo "Build number read from argument: $provided" >&2
elif [[ "$MUMBLE_VERSION" =~ ^v?[0-9]+\.[0-9]+\.([0-9]+)(-.+)?$ ]]; then
	provided="${BASH_REMATCH[1]}"
	echo "Build number read from version: $provided" >&2
fi

if ! [[ -z "$provided" || "$provided" =~ ^[0-9]+$ ]]; then
	echo "Error: invalid build number '$provided'" >&2
	exit 1
fi

fetched=-1
if [[ -f "$BUILD_NUMBER_SCRIPT" && -f "$VERSION_SCRIPT" ]]; then
	version=$( cd "$REPO_DIR" && python3 "$VERSION_SCRIPT" )
	commit=$( git -C "$REPO_DIR" rev-parse HEAD )
	if ! fetched=$( timeout 20 python3 "$BUILD_NUMBER_SCRIPT" --commit "$commit" --version "$version" --default -1 ); then
		fetched=-1
	fi
	[[ "$fetched" =~ ^[0-9]+$ ]] || fetched=-1
else
	echo "Build number scripts not found" >&2
fi

if [[ "$fetched" -ge 0 ]]; then
	if [[ -n "$provided" && "$provided" -ne 0 && "$provided" -ne "$fetched" ]]; then
		echo "Error: provided build number $provided does not match the build number $fetched fetched for commit $commit" >&2
		exit 1
	fi
	echo "Determined build number to be $fetched" >&2
	echo "$fetched"
else
	echo "Failed to fetch the build number, using ${provided:-0}" >&2
	echo "${provided:-0}"
fi
