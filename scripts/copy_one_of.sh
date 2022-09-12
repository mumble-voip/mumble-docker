#!/usr/bin/env bash

# This script can be used to copy the first existing file to the
# target destination.
# Thus
# copy_one_of.sh a b c
# copies either a or b to c. The first of the target files that
# exists will be copied. The rest will be ignored.

set -e
set -x

if [[ "$#" < 2 ]]; then
	>&2 echo "Too few arguments - expected at least two"
	exit 1
fi

parameters=( "$@" )
target_file="${parameters[$(( $# - 1))]}"

found=false

# Make use of num. of arguments $# to iterate up to the i - 1st argument (last one is destination)
for i in $(seq 0 $(( $# - 2 )) ); do 
	current_file=${parameters[$i]}

	if [[ -f "$current_file" ]]; then
		cp "$current_file" "$target_file"
		found=true
		break
	fi
done

if [[ "$found" = "false" ]]; then
	>&2 echo "Did not find any of the source files - nothing was copied"
	exit 1
fi
