#!/usr/bin/env bash

set -e
set -x

if [[ "$QT_VERSION" = 6 ]]; then
	QT_PACKAGES=(\
		qt6-base-dev \
		qt6-tools-dev \
		qt6-tools-dev-tools \
		qt6-qpa-plugins \
	)
elif [[ "$QT_VERSION" = 5 ]]; then
	QT_PACKAGES=(\
		qtbase5-dev \
		qttools5-dev \
		qttools5-dev-tools
	)
else
	1>&2 echo "Error, unknown Qt version: '$QT_VERSION'"
	exit 1
fi

apt install --no-install-recommends -y "${QT_PACKAGES[@]}"
