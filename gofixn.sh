#!/bin/sh

CMPLINT="$(which cmplint)"
if [ -z "$CMPLINT" ]; then
  go install fillmore-labs.com/cmplint@latest
  CMPLINT="$(go env GOPATH)/bin/cmplint"
fi
[ -x "$CMPLINT" ] || exit 1

go env -w CC=cc CXX=c++ CGO_ENABLED=1

EXCLUDES="$(pwd)/excludes"
PROFILES="$(pwd)/profiles"
LOGS="$(pwd)/logs"

mkdir -p "$PROFILES" "$LOGS"

i="$(go env GOROOT)/src"
I="golang_go"
for j in cmplint newlint ; do
  LOG="$LOGS/${I}_$j.log"
  if [ ! -e "$LOG" ]; then
    case $j in
      cmplint)
        FLAGS="-c=0"
        ;;
      newlint)
        FLAGS="-c=0 -check-is=false"
        ;;
    esac
    echo "Running cmplint on $i, $j pass..."
    (cd "$i" &&  "$CMPLINT" $FLAGS ./... ) 2> "$LOGS/${I}_$j.log"
  # else echo "Skipping $i, $j pass..."
  fi
done
