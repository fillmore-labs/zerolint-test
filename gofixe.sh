#!/bin/sh

ERRORTYPE="$(which errortype)"
if [ -z "$ERRORTYPE" ]; then
  go install fillmore-labs.com/errortype@latest
  ERRORTYPE="$(go env GOPATH)/bin/errortype"
fi
[ -x "$ERRORTYPE" ] || exit 1

go env -w CC=cc CXX=c++ CGO_ENABLED=1

LOGS="$(pwd)/logs"

mkdir -p "$LOGS"

i="$(go env GOROOT)/src"
I="golang_go"
for j in errortype errordebug ; do
  LOG="$LOGS/${I}_$j.log"
  if [ ! -e "$LOG" ]; then
    case $j in
      errortype)
        FLAGS="-c=0 -stylecheck=false"
        ;;
      errordebug)
        FLAGS="-c=0 -check-is=false -deep-is-check -unchecked-assert -trace -suggest=$OVERRIDE.new"
        ;;
    esac
    echo "Running errortype on $i, $j pass..."
    (cd "$i" &&  "$ERRORTYPE" $FLAGS ./... ) 2> "$LOGS/${I}_$j.log"
  # else echo "Skipping $i, $j pass..."
  fi
done
