#!/usr/bin/env bash

set -e
set -x

BRANCH_ARGS=()
if [[ -n "$MUMBLE_VERSION" && ! "$MUMBLE_VERSION" == "latest" ]]; then
	# --branch also accepts tags. Selecting the version here (instead of
	# checking it out afterwards) makes sure the submodules are cloned at the
	# commits pinned by that version.
	BRANCH_ARGS=(--branch "$MUMBLE_VERSION")
fi

git clone --depth 1 --recurse-submodules --shallow-submodules -c advice.detachedHead=false "${BRANCH_ARGS[@]}" https://github.com/mumble-voip/mumble/ /mumble/repo
