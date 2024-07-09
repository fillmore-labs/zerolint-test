#!/bin/sh

ZEROLINT="$(which zerolint)"
if [ -z "$ZEROLINT" ]; then
  go install fillmore-labs.com/zerolint@latest
  ZEROLINT="$(go env GOPATH)/bin/zerolint"
fi
[ -x "$ZEROLINT" ] || exit 1

go env -w CC=cc CXX=c++ CGO_ENABLED=1

EXCLUDES="$(pwd)/excludes"
PROFILES="$(pwd)/profiles"
LOGS="$(pwd)/logs"

mkdir -p "$PROFILES" "$LOGS"

i="$(go env GOROOT)/src"
I="golang_go"
if [ ! -r "$EXCLUDES/$I.txt" ]; then
  echo "# zerolint exclusions for $i" > "$EXCLUDES/$I.txt"
fi
for j in lint elint ntlint fulllint; do
  LOG="$LOGS/${I}_$j.log"
  if [ ! -e "$LOG" ]; then
    case $j in
      lint)
        FLAGS="-c=0"
        ;;
      elint)
        FLAGS="-level=extended -c=0"
        ;;
      ntlint)
        FLAGS="-level=full -test=false -zerotrace -c=0"
        ;;
      fulllint)
        FLAGS="-level=full -generated -zerotrace -c=0"
        ;;
    esac
    echo "Running zerolint on $i, $j pass..."
    (cd "$i" &&  "$ZEROLINT" $FLAGS ./... ) 2> "$LOGS/${I}_$j.log"
  # else echo "Skipping $i, $j pass..."
  fi
done
