#!/bin/sh

for i in temp/*/*; do
  if [ ! -d $i ]; then
    echo "run ./prepare.sh first"
    exit 1
  fi
  echo "Running restore on $i..."
  (cd $i && git restore :/)
done
