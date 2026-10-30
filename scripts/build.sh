#!/usr/bin/env bash

set -e
set -x

BUILD_NUMBER_SCRIPT="/mumble/repo/scripts/mumble-build-number.py"
VERSION_SCRIPT="/mumble/repo/scripts/mumble-version.py"

buildNumber=0
if [[ ! -z "$MUMBLE_BUILD_NUMBER" ]]; then
	buildNumber=$MUMBLE_BUILD_NUMBER
	echo "Build number read from argument: $buildNumber"
elif [[ "$MUMBLE_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	buildNumber=$(echo "$MUMBLE_VERSION" | sed -E 's/v[0-9]+\.[0-9]+\.([0-9]+)/\1/' )
	echo "Build number read from version: $buildNumber"
else
	if [[ -f "$BUILD_NUMBER_SCRIPT" && -f "$VERSION_SCRIPT" ]]; then
		version=$( python3 "$VERSION_SCRIPT" )
		commit=$( git rev-parse HEAD )
		buildNumber=$( timeout 20 python3 "$BUILD_NUMBER_SCRIPT" --commit "$commit" --version "$version" --default -1 || exitStatus=$? )
		
		if [[ "$exitStatus" -eq 0 && "$buildNumber" -ge 0 ]]; then
			echo "Determined build number to be $buildNumber"
		else
			echo "Failed to fetch the build number for commit $commit, defaulting to 0"
			buildNumber=0
		fi
	else
		echo "Defaulting to build number 0"
	fi
fi

if [[ -f "./cmake/mumble_dependency_provider.cmake" ]]; then
	MUMBLE_CMAKE_ARGS="$MUMBLE_CMAKE_ARGS -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=cmake/mumble_dependency_provider.cmake"
fi

cmake \
	-B build \
	-S .\
	-DCMAKE_BUILD_TYPE=Release \
	-DBUILD_NUMBER=$buildNumber \
	-Dclient=OFF \
	-Dserver=ON \
	-Dice=ON \
	-Dtests=ON \
	-Dwarnings-as-errors=OFF \
	-Dzeroconf=OFF \
	-DCMAKE_UNITY_BUILD=ON \
	$MUMBLE_CMAKE_ARGS

cmake --build build -j $(nproc)

TEST_TIMEOUT=600 # seconds
export QTEST_FUNCTION_TIMEOUT="$(( $TEST_TIMEOUT * 1000 ))" # milliseconds
ctest build --timeout $TEST_TIMEOUT --output-on-failure . -j $(nproc)
