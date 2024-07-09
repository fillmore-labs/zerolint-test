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
  for j in lint nlint fulllint fixlint first second finallint; do
    LOG="$LOGS/${I}_$j.log"
    if [ ! -e "$LOG" ]; then
      case $j in
        lint)
          (cd $i && git restore :/)
          case $i in
            temp/grafana/grafana)
              if [ ! -e "$i/pkg/server/wire_gen.go" ]; then
                (cd "$i" && "$WIRE" gen -tags oss ./pkg/server)
              fi
              ;;
            temp/bazelbuild/bazelisk|temp/nats-io/nats.go)
              (cd "$i" && go mod tidy)
              ;;
          esac
          FLAGS="-c 0"
          ;;
        nlint)
          FLAGS="-level full -c 0"
          ;;
        fulllint)
          FLAGS="-level full -generated -c 0"
          ;;
        fixlint)
          FLAGS="-level full -zerotrace -excluded $EXCLUDES/$I.txt -c 0"
          ;;
        finallint)
          FLAGS="-level full -excluded $EXCLUDES/$I.txt"
          ;;
        *)
          # PROFILE="-cpuprofile \"$PROFILES/${I}_$j.prof\" "
          FLAGS="-level full -zerotrace -excluded $EXCLUDES/$I.txt -fix"
          ;;
      esac
      echo "Running zerolint on $i, $j pass..."
      find $i -type d \(\
        -name _asm -o \
        -name .bingo -o \
        -path temp/99designs/gqlgen/_examples -o \
        -path temp/apache/dubbo-go/tools/dubbogo-cli/cmd/testGenCode/template -o \
        -path temp/aws/copilot-cli/regression/multi-svc-app/www -o \
        -path temp/cloudevents/sdk-go/test/benchmark -o \
        -path temp/cue-lang/cue/internal/golangorgx/vendoring -o \
        -path temp/etcd-io/etcd/tools/mod -o \
        -path temp/go-gorm/gorm/tests -o \
        -path temp/go-language-server/protocol/tools -o \
        -path temp/go101/golds/internal/testing/examples -o \
        -path temp/goccy/go-yaml/benchmarks -o \
        -path temp/goccy/go-yaml/docs/playground -o \
        -path temp/gohugoio/hugo/docs -o \
        -path temp/golang/exp/shiny -o \
        -path temp/golang/vscode-go/docs -o \
        -path temp/golang/vscode-go/extension/test/testdata -o \
        -path temp/golangci/golangci-lint/pkg/golinters/\*/testdata -o \
        -path temp/golingon/lingon/docs -o \
        -path temp/gomodules/jsonpatch/v3/vendor/gopkg.in/yaml.v2 -o \
        -path temp/google/go-github/example/newreposecretwithlibsodium -o \
        -path temp/google/osv-scanner/cmd/osv-scanner/scan/source/fixtures/go-project -o \
        -path temp/google/osv-scanner/experimental/javareach -o \
        -path temp/GoogleContainerTools/kpt-config-sync/test/docker/presync-webhook-server -o \
        -path temp/GoogleContainerTools/skaffold/examples/grpc-e2e-tests/service -o \
        -path temp/GoogleContainerTools/skaffold/examples/grpc-e2e-tests/tests -o \
        -path temp/GoogleContainerTools/skaffold/integration/examples/grpc-e2e-tests/service -o \
        -path temp/GoogleContainerTools/skaffold/integration/examples/grpc-e2e-tests/tests -o \
        -path temp/grafana/grafana/.citools -o \
        -path temp/grafana/grafana/devenv -o \
        -path temp/grafana/grafana/hack -o \
        -path temp/grafana/grafana/scripts -o \
        -path temp/grafana/pyroscope/ebpf -o \
        -path temp/grafana/pyroscope/examples/\*/golang-push -o \
        -path temp/grafana/pyroscope/og -o \
        -path temp/heetch/avro/cmd/avrogo/testdata -o \
        -path temp/jaegertracing/jaeger/docker/debug -o \
        -path temp/kubeedge/kubeedge/staging/src/github.com/kubeedge/mapper-framework/_template -o \
        -path temp/kubernetes-sigs/kubebuilder/testdata -o \
        -path temp/kubernetes-sigs/kueue/hack/internal/tools -o \
        -path temp/kubernetes-sigs/kueue/site -o \
        -path temp/kubernetes/dashboard/modules/common/tools -o \
        -path temp/kubernetes/klog/examples/coexist_klog_v1_and_v2 -o \
        -path temp/kubernetes/kops/hack -o \
        -path temp/kubernetes/kops/tools/otel/traceserver -o \
        -path temp/kubernetes/kubernetes/hack/tools -o \
        -path temp/kubernetes/kubernetes/staging/src/k8s.io/kms/internal/plugins/_mock -o \
        -path temp/launchdarkly/go-server-sdk/ldotel -o \
        -path temp/launchdarkly/go-server-sdk/testservice -o \
        -path temp/mindersec/minder/tools -o \
        -path temp/minio/minio/docs/debugging/inspect -o \
        -path temp/mvdan/sh/_js -o \
        -path temp/onsi/ginkgo/ginkgo/performance/_fixtures/performance_fixture -o \
        -path temp/prometheus/prometheus/internal/tools -o \
        -path temp/reddit/achilles-sdk/tools -o \
        -path temp/sigstore/k8s-manifest-sigstore/example -o \
        -path temp/sigstore/rekor/hack/tools -o \
        -path temp/sigstore/sigstore/hack/tools -o \
        -path temp/spf13/viper/remote -o \
        -path temp/spotify/confidence-sdk-go/demo -o \
        -path temp/tailscale/tailscale/gokrazy/\*/builddir -o \
        -path temp/thomaspoignant/go-feature-flag/website/.ci -o \
        -path temp/uber-go/mock/bazel -o \
        -path temp/vektra/mockery/internal/fixtures/example_project/pkg_with_submodules -o \
        -path temp/vektra/mockery/tools \
        \) -prune -o \
      -name go.mod -execdir "$ZEROLINT" $FLAGS ./... \; 2> "$LOGS/${I}_$j.log"
    # else echo "Skipping $i, $j pass..."
    fi
  done
done
