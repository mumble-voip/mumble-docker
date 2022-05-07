#!/usr/bin/env bash

set -e

BUILD_NUMBER_SCRIPT="/mumble/repo/scripts/mumble-build-number.py"
VERSION_SCRIPT="/mumble/repo/scripts/mumble-version.py"

mkdir build && cd build

buildNumber=0
if [[ "$MUMBLE_VERSION" =~ '^v[0-9]+\.[0-9]+\.[0-9]+' ]]; then
	buildNumber=$(echo "$MUMBLE_VERSION" | sed -E 's/v[0-9]+\.[0-9]+\.([0-9]+)/\1/' )
	echo "Build number read from version: $buildNumber"
else
	if [[ -f "$BUILD_NUMBER_SCRIPT" && -f "$VERSION_SCRIPT" ]]; then
		version=$( python3 "$VERSION_SCRIPT" )
		commit=$( git rev-parse HEAD )
		buildNumber=$( python3 "$BUILD_NUMBER_SCRIPT" --commit "$commit" --version "$version" --default -1 )

		if [[ "$buildNumber" -ge 0 ]]; then
			echo "Determined build number to be $buildNumber"
		else
			echo "Failed to fetch the build number for commit $commit, defaulting to 0"
			buildNumber=0
		fi
	else
		echo "Defaulting to build number 0"
	fi
fi

cmake \
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_NUMBER=$buildNumber \
	-Dclient=OFF \
	-Dserver=ON \
	-Dice=ON \
	-Dtests=ON \
	-Dwarnings-as-errors=OFF \
	-Dzeroconf=OFF \
	$MUMBLE_CMAKE_ARGS \
	..

cmake --build . -j $(nproc)

ctest --output-on-failure .