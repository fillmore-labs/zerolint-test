#!/bin/sh

echo "Viewing diffs..."
for i in temp/*/*; do
  (cd $i && git diff -u)
done
