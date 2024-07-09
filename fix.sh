#!/bin/sh

ZEROLINT="$(which zerolint)"
if [ -z "$ZEROLINT" ]; then
  go install fillmore-labs.com/zerolint@latest
  ZEROLINT="$(go env GOPATH)/bin/zerolint"
fi
[ -x "$ZEROLINT" ] || exit 1

WIRE="$(which wire)"
if [ -z "$WIRE" ]; then
  go install github.com/google/wire/cmd/wire@latest
  WIRE="$(go env GOPATH)/bin/wire"
fi
[ -x "$WIRE" ] || exit 1

go env -w CC=cc CXX=c++ CGO_ENABLED=1

EXCLUDES="$(pwd)/excludes"

for i in temp/*/*; do
  if [ ! -d $i ]; then
    echo "run ./prepare.sh first"
    exit 1
  fi
  if [ ! -r "$EXCLUDES/$i.txt" ]; then
    echo "# zerolint exclusions for $i" > "$EXCLUDES/$i.txt"
  fi
  case $i in
    temp/grafana/grafana)
      (cd temp/grafana/grafana && "$WIRE" gen -tags oss ./pkg/server)
      ;;
  esac
  for j in first second; do
    echo "Running zerolint on $i, $j pass..."
    find $i -type d \(\
      -name _asm -o \
      -path temp/99designs/gqlgen/_examples -o \
      -path temp/AdguardTeam/AdGuardHome/internal/tools -o \
      -path temp/etcd-io/etcd/tools/mod -o \
      -path temp/gohugoio/hugo/docs -o \
      -path temp/golang/vscode-go/extension/test/testdata -o \
      -path temp/golang/vscode-go/docs -o \
      -path temp/golangci/golangci-lint/pkg/golinters/\*/testdata -o \
      -path temp/golingon/lingon/docs -o \
      -path temp/google/go-github/example/newreposecretwithlibsodium -o \
      -path temp/grafana/grafana/.bingo -o \
      -path temp/grafana/grafana/devenv -o \
      -path temp/grafana/grafana/hack -o \
      -path temp/grafana/grafana/scripts -o \
      -path temp/jaegertracing/jaeger/docker/debug -o \
      -path temp/kubernetes/kubernetes/hack/tools -o \
      -path temp/kubernetes/kubernetes/staging/src/k8s.io/kms/internal/plugins/_mock -o \
      -path temp/launchdarkly/go-server-sdk/ldotel -o \
      -path temp/launchdarkly/go-server-sdk/testservice -o \
      -path temp/mvdan/sh/_js -o \
      -path temp/tailscale/tailscale/gokrazy/\*/builddir -o \
      -path temp/thomaspoignant/go-feature-flag/website/.ci -o \
      -path temp/vektra/mockery/pkg/fixtures/example_project/pkg_with_submodules -o \
      -path temp/vektra/mockery/tools \
      \) -prune -o \
    -name go.mod -execdir "$ZEROLINT" -excluded "$EXCLUDES/$i.txt" -zerotrace -fix ./... \;
  done
done
