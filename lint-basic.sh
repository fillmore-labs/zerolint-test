#!/bin/sh

ZEROLINT="$(which zerolint)"
if [ -z "$ZEROLINT" ]; then
  go install fillmore-labs.com/zerolint@latest
  ZEROLINT="$(go env GOPATH)/bin/zerolint"
fi
[ -x "$ZEROLINT" ] || exit 1

for i in temp/*/*; do
  if [ ! -d $i ]; then
    echo "run ./prepare.sh first"
    exit 1
  fi
  echo "Running zerolint on $i..."
  find $i -type d \(\
    -name _asm -o \
    -path temp/99designs/gqlgen/_examples -o \
    -path temp/etcd-io/etcd/tools/mod -o \
    -path temp/gohugoio/hugo/docs -o \
    -path temp/golingon/lingon/docs -o \
    -path temp/kubernetes/kubernetes/hack/tools -o \
    -path temp/prometheus/prometheus/documentation/examples/remote_storage -o \
    -path temp/tailscale/tailscale/gokrazy/\*/builddir \
    \) -prune -o \
  -name go.mod -execdir "$ZEROLINT" -basic -zerotrace -c 1 ./... \;
done
