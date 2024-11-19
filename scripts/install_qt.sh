#!/usr/bin/env bash

set -e
set -x

if [[ "$QT_VERSION" = 6 ]]; then
	QT_PACKAGES=(\
		libqt6core6 \
		libqt6network6 \
		libqt6sql6 \
		libqt6sql6-mysql \
		libqt6sql6-psql \
		libqt6sql6-sqlite \
		libqt6xml6 \
		libqt6dbus6 \
	)
elif [[ "$QT_VERSION" = 5 ]]; then
	QT_PACKAGES=(\
		libqt5core5a \
		libqt5network5 \
		libqt5sql5 \
		libqt5sql5-mysql \
		libqt5sql5-psql \
		libqt5sql5-sqlite \
		libqt5xml5 \
		libqt5dbus5 \
	)
else
	1>&2 echo "Error, unknown Qt version: '$QT_VERSION'"
	exit 1
fi

apt install --no-install-recommends -y "${QT_PACKAGES[@]}"
