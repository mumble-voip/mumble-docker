#!/usr/bin/env bash

set -e
set -x

case "${MUMBLE_VERSION}" in
	v1.4.* )  ;& # fallthrough
	1.4.*  )  ;& # fallthrough
	v1.5.* )  ;& # fallthrough
	1.5.*  )  QT_VERSION=5
		;;
	v1.6.* )  ;& # fallthrough
	1.6.*  )  ;& # fallthrough
	latest )  ;& # fallthrough
	*      )  QT_VERSION=6
		;;
esac

if [[ -z "$QT_VERSION" ]]; then
	1>&2 echo "Error: unable to determine Qt version from MUMBLE_VERSION=$MUMBLE_VERSION"
	exit 1
fi

echo -n "$QT_VERSION"
