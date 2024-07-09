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

go env -w CC=cc CXX=c++ CGO_ENABLED=1 GOEXPERIMENT=synctest

EXCLUDES="$(pwd)/excludes"
PROFILES="$(pwd)/profiles"
LOGS="$(pwd)/logs"

mkdir -p "$PROFILES" "$LOGS"

for i in temp/*/*; do
  if [ ! -d $i ]; then
    echo "run ./prepare.sh first"
    exit 1
  fi
  I="$(echo $i | sed -e 's#^temp/\([^/]*\)/\([^/]*\)$#\1_\2#')"
  if [ ! -r "$EXCLUDES/$I.txt" ]; then
    echo "# zerolint exclusions for $i" > "$EXCLUDES/$I.txt"
  fi
  case $i in
    temp/grafana/grafana)
      if [ ! -e "$i/pkg/server/wire_gen.go" ]; then
        (cd "$i" && "$WIRE" gen -tags oss ./pkg/server)
      fi
      ;;
  esac
  for j in lint first second; do
    LOG="$LOGS/${I}_$j.log"
    if [ -e "$LOG" ]; then
      echo "Skipping $i, $j pass..."
    else
      case $j in
        lint)
          FLAGS=""
          ;;
        *)
          # PROFILE="-cpuprofile \"$PROFILES/${I}_$j.prof\" "
          FLAGS="-full $PROFILE -excluded \"$EXCLUDES/$I.txt\" -zerotrace -fix"
          ;;
      esac
      echo "Running zerolint on $i, $j pass..."
      find $i -type d \(\
        -name _asm -o \
        -path temp/99designs/gqlgen/_examples -o \
        -path temp/AdguardTeam/AdGuardHome/internal/tools -o \
        -path temp/cue-lang/cue/internal/golangorgx/vendoring -o \
        -path temp/etcd-io/etcd/tools/mod -o \
        -path temp/go-language-server/protocol/tools -o \
        -path temp/go101/golds/internal/testing/examples -o \
        -path temp/goccy/go-yaml/benchmarks -o \
        -path temp/goccy/go-yaml/docs/playground -o \
        -path temp/gohugoio/hugo/docs -o \
        -path temp/golang/vscode-go/docs -o \
        -path temp/golang/vscode-go/extension/test/testdata -o \
        -path temp/golangci/golangci-lint/pkg/golinters/\*/testdata -o \
        -path temp/golingon/lingon/docs -o \
        -path temp/google/go-github/example/newreposecretwithlibsodium -o \
        -path temp/google/osv-scanner/cmd/osv-scanner/fixtures/go-project -o \
        -path temp/grafana/grafana/.bingo -o \
        -path temp/grafana/grafana/devenv -o \
        -path temp/grafana/grafana/hack -o \
        -path temp/grafana/grafana/scripts -o \
        -path temp/grafana/pyroscope/ebpf -o \
        -path temp/grafana/pyroscope/examples/\*/golang-push -o \
        -path temp/grafana/pyroscope/og -o \
        -path temp/hashicorp/consul/internal/tools/proto-gen-rpc-glue/e2e/consul -o \
        -path temp/jaegertracing/jaeger/docker/debug -o \
        -path temp/kubernetes/kubernetes/hack/tools -o \
        -path temp/kubernetes/kubernetes/staging/src/k8s.io/kms/internal/plugins/_mock -o \
        -path temp/launchdarkly/go-server-sdk/ldotel -o \
        -path temp/launchdarkly/go-server-sdk/testservice -o \
        -path temp/mvdan/sh/_js -o \
        -path temp/slack-go/slack/examples/workflow_step -o \
        -path temp/tailscale/tailscale/gokrazy/\*/builddir -o \
        -path temp/thomaspoignant/go-feature-flag/website/.ci -o \
        -path temp/vektra/mockery/internal/fixtures/example_project/pkg_with_submodules -o \
        -path temp/vektra/mockery/tools \
        \) -prune -o \
      -name go.mod -execdir "$ZEROLINT" $FLAGS ./... \; 2> "$LOGS/${I}_$j.log"
    fi
  done
done
