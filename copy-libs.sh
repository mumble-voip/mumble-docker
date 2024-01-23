#!/bin/sh
if [ $# -lt 2 ]
then
  echo "Too few arguments. Run copy-libs.sh <binary or shared lib to analyze> <target directory>"
  exit 1
fi

binary_path=$1
target_path=$2

mkdir -p "$2"
for i in $(ldd "$binary_path" | grep "=>" | awk -F ' => ' '{print $2}' | cut -d ' ' -f1)
do
  echo "Copying $i"
  cp -f "$i" "$2"
done