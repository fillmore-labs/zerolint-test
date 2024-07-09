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

MOCKGEN="$(which mockgen)"
if [ -z "$MOCKGEN" ]; then
  go install go.uber.org/mock/mockgen@latest
  MOCKGEN="$(go env GOPATH)/bin/mockgen"
fi
[ -x "$MOCKGEN" ] || exit 1

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
  IGNORE=
  case $i in
    temp/wal-g/wal-g)
      if [ ! -r "/usr/include/sodium.h" ]; then
        IGNORE=true
      fi
      ;;
  esac
  FIRST=true
  for j in lint elint nlint ntlint fulllint fixlint first second finallint; do
    LOG="$LOGS/${I}_$j.log"
    if [ ! "$IGNORE" -a ! -e "$LOG" ]; then
      if "$FIRST"; then
        (cd $i && git restore :/)
        case $i in
          temp/argoproj/argo-workflows)
            mkdir -p "$i/ui/dist/app" && touch "$i/ui/dist/app/empty"
            ;;
          temp/traefik/traefik)
            mkdir -p "$i/webui/static" && touch "$i/webui/static/empty"
            ;;
          temp/google/go-cloud)
            find "$i"/*/ -name go.mod -execdir go mod tidy \;
            ;;
          temp/grafana/grafana)
            if [ ! -e "$i/pkg/server/wire_gen.go" ]; then
              (cd "$i" && "$WIRE" gen -tags oss ./pkg/server)
            fi
            ;;
          temp/bazelbuild/bazelisk|temp/nats-io/nats.go|temp/go-yaml/yaml|temp/redpanda-data/connect|temp/Netflix/chaosmonkey)
            (cd "$i" && go mod tidy)
            ;;
          temp/DataDog/datadog-agent)
            (cd "$i" && go work edit -dropgodebug=tlskyber)
            ;;
          temp/open-feature/go-sdk)
            (cd "$i" && \
              "$MOCKGEN" -source=openfeature/provider.go -destination=openfeature/provider_mock.go -package=openfeature && \
              "$MOCKGEN" -source=openfeature/hooks.go -destination=openfeature/hooks_mock.go -package=openfeature && \
              "$MOCKGEN" -source=openfeature/interfaces.go -destination=openfeature/interfaces_mock.go -package=openfeature )
            ;;
          temp/envoyproxy/go-control-plane)
            (cd "$i/envoy" && go mod tidy)
            ;;
          temp/zalando/postgres-operator)
            (cd "$i" && go generate ./...)
            sed -i'' -e "s#go\\.uber\\.org#github.com/golang#g" "$i"/mocks/*.go
            ;;
          temp/fluxcd/flux2)
            mkdir -p "$i"/cmd/flux/manifests && touch "$i"/cmd/flux/manifests/.yaml
            ;;
        esac
        FIRST=false
      fi
      case $i in
        temp/dapr/dapr|temp/dapr/kit)
          CMD="go vet -vettool=$ZEROLINT -tags=unit"
          ;;
        temp/k8snetworkplumbingwg/whereabouts)
          CMD="go vet -vettool=$ZEROLINT -tags=test"
          ;;
        *)
          CMD="$ZEROLINT"
          ;;
      esac
      case $j in
        lint)
          FLAGS="-c=0"
          ;;
        elint)
          FLAGS="-level=extended -c=0"
          ;;
        nlint)
          FLAGS="-level=full -c=0"
          ;;
        ntlint)
          FLAGS="-level=full -test=false -zerotrace -c=0"
          ;;
        fulllint)
          FLAGS="-level=full -generated  -zerotrace -c=0"
          ;;
        fixlint)
          FLAGS="-level=full -zerotrace -excluded $EXCLUDES/$I.txt -c=0"
          ;;
        finallint)
          FLAGS="-level=full -excluded $EXCLUDES/$I.txt"
          ;;
        *)
          # PROFILE="-cpuprofile \"$PROFILES/${I}_$j.prof\" "
          FLAGS="-level=full -zerotrace -excluded $EXCLUDES/$I.txt -fix"
          ;;
      esac
      echo "Running zerolint on $i, $j pass..."
      find $i -type d \(\
        -name _asm \
        -o -name .bingo \
        -o -name testdata \
        -o -path temp/99designs/gqlgen/_examples \
        -o -path temp/GoogleContainerTools/kpt-config-sync/test/docker/presync-webhook-server \
        -o -path temp/GoogleContainerTools/skaffold/examples/grpc-e2e-tests/service \
        -o -path temp/GoogleContainerTools/skaffold/examples/grpc-e2e-tests/tests \
        -o -path temp/GoogleContainerTools/skaffold/integration/examples/grpc-e2e-tests/service \
        -o -path temp/GoogleContainerTools/skaffold/integration/examples/grpc-e2e-tests/tests \
        -o -path temp/IBM/sarama/examples \
        -o -path temp/RichardKnop/machinery/v2 \
        -o -path temp/TykTechnologies/tyk/ci \
        -o -path temp/VictoriaMetrics/VictoriaMetrics/app/vmui/packages/vmui/web \
        -o -path temp/ZeroHawkeye/wordZero/benchmark/golang \
        -o -path temp/anchore/syft/cmd/syft/internal/test/integration/test-fixtures \
        -o -path temp/anchore/syft/syft/pkg/cataloger/golang/test-fixtures \
        -o -path temp/apache/dubbo-go/tools/dubbogo-cli/cmd/testGenCode/template \
        -o -path temp/aquaproj/aqua/tests \
        -o -path temp/asynkron/protoactor-go/examples/cluster-broadcast \
        -o -path temp/asynkron/protoactor-go/examples/cluster-error-response \
        -o -path temp/asynkron/protoactor-go/examples/remote-ssl \
        -o -path temp/aws/copilot-cli/regression/multi-svc-app/www \
        -o -path temp/bufbuild/protocompile/internal/tools \
        -o -path temp/capnproto/go-capnp/example \
        -o -path temp/charmbracelet/bubbletea/examples \
        -o -path temp/charmbracelet/bubbletea/tutorials \
        -o -path temp/charmbracelet/lipgloss/examples \
        -o -path temp/cloudevents/sdk-go/test/benchmark \
        -o -path temp/cosmos/cosmos-sdk/tests/systemtests \
        -o -path temp/cosmos/gaia/tests/interchain \
        -o -path temp/cue-lang/cue/internal/golangorgx/vendoring \
        -o -path temp/depot/cli/examples \
        -o -path temp/elazarl/goproxy/examples \
        -o -path temp/emprcl/runal/examples \
        -o -path temp/envoyproxy/go-control-plane/examples/dyplomat \
        -o -path temp/envoyproxy/go-control-plane/internal/tools \
        -o -path temp/etcd-io/etcd/tools/mod \
        -o -path temp/etcd-io/raft/tools/mod \
        -o -path temp/flyteorg/flyte/boilerplate/flyte/golang_support_tools \
        -o -path temp/gnolang/gno/gno.land/pkg/gnoweb/tools \
        -o -path temp/gnolang/gno/misc/devdeps \
        -o -path temp/gnolang/gno/misc/stress-test/stress-test-many-posts \
        -o -path temp/go-acme/lego/docs \
        -o -path temp/go-critic/go-critic/tools \
        -o -path temp/go-gorm/gorm/tests \
        -o -path temp/go-language-server/protocol/tools \
        -o -path temp/go101/golds/internal/testing/examples \
        -o -path temp/goccy/go-yaml/benchmarks \
        -o -path temp/goccy/go-yaml/docs/playground \
        -o -path temp/gofiber/contrib/fibernewrelic \
        -o -path temp/gofiber/contrib/hcaptcha \
        -o -path temp/gofiber/contrib/otelfiber/example \
        -o -path temp/gofiber/recipes/https-pkcs12-tls \
        -o -path temp/gofiber/recipes/unit-test \
        -o -path temp/gohugoio/hugo/docs \
        -o -path temp/golang/exp/shiny \
        -o -path temp/golang/vscode-go/docs \
        -o -path temp/golingon/lingon/docs \
        -o -path temp/gomods/athens/docs \
        -o -path temp/gomodules/jsonpatch/v3/vendor/gopkg.in/yaml.v2 \
        -o -path temp/google/cel-go/codelab \
        -o -path temp/google/cel-go/policy \
        -o -path temp/google/cel-go/repl \
        -o -path temp/google/go-github/example/newreposecretwithlibsodium \
        -o -path temp/google/osv-scanner/cmd/osv-scanner/scan/source/fixtures/go-project \
        -o -path temp/google/osv-scanner/experimental/javareach \
        -o -path temp/goptics/varmq/examples \
        -o -path temp/goreleaser/goreleaser/dagger \
        -o -path temp/grafana/grafana/.citools \
        -o -path temp/grafana/grafana/devenv \
        -o -path temp/grafana/grafana/hack \
        -o -path temp/grafana/grafana/scripts \
        -o -path temp/grafana/pyroscope/ebpf \
        -o -path temp/grafana/pyroscope/examples/\*/golang-push \
        -o -path temp/grafana/pyroscope/og \
        -o -path temp/grpc-ecosystem/go-grpc-middleware/examples \
        -o -path temp/grpc-ecosystem/go-grpc-middleware/interceptors/logging/examples \
        -o -path temp/hashicorp/go-secure-stdlib/configutil \
        -o -path temp/hashicorp/vault/tools/pipeline \
        -o -path temp/hashicorp/vault/vault/hcp_link/proto \
        -o -path temp/hyperledger/firefly/smart_contracts/fabric \
        -o -path temp/hyperledger/firefly/test/data/contracts/assetcreator \
        -o -path temp/jaegertracing/jaeger/scripts/build/docker/debug \
        -o -path temp/klauspost/compress/s2/cmd/_s2sx \
        -o -path temp/klauspost/compress/zstd/_generate \
        -o -path temp/kubeedge/kubeedge/staging/src/github.com/kubeedge/mapper-framework/_template \
        -o -path temp/kubernetes-sigs/kube-api-linter/tools \
        -o -path temp/kubernetes-sigs/kueue/hack/internal/tools \
        -o -path temp/kubernetes-sigs/kueue/site \
        -o -path temp/kubernetes-sigs/prow/hack/tools \
        -o -path temp/kubernetes-sigs/prow/site \
        -o -path temp/kubernetes/dashboard/modules/common/tools \
        -o -path temp/kubernetes/klog/examples/coexist_klog_v1_and_v2 \
        -o -path temp/kubernetes/kops/hack \
        -o -path temp/kubernetes/kops/tools/metal/storage \
        -o -path temp/kubernetes/kops/tools/otel/traceserver \
        -o -path temp/kubernetes/kubernetes/hack/tools \
        -o -path temp/kubernetes/kubernetes/staging/src/k8s.io/kms/internal/plugins/_mock \
        -o -path temp/launchdarkly/go-server-sdk/ldotel \
        -o -path temp/launchdarkly/go-server-sdk/testservice \
        -o -path temp/mattermost/mattermost/server \
        -o -path temp/mindersec/minder/tools \
        -o -path temp/minio/minio-go/examples \
        -o -path temp/minio/minio/docs/debugging/inspect \
        -o -path temp/mongodb/mongo-go-driver/examples/_logger \
        -o -path temp/mongodb/mongo-go-driver/internal/test/compilecheck \
        -o -path temp/mongodb/mongo-go-driver/internal/test/compilecheck \
        -o -path temp/muesli/termenv/examples/ssh \
        -o -path temp/mvdan/sh/_js \
        -o -path temp/nephio-project/porch/third_party/GoogleContainerTools/kpt-functions-sdk/go \
        -o -path temp/onsi/ginkgo/ginkgo/performance/_fixtures/performance_fixture \
        -o -path temp/open-telemetry/opentelemetry-collector/config/configtls \
        -o -path temp/openbao/go-secure-stdlib/plugincontainer \
        -o -path temp/ory/hydra/internal/httpclient \
        -o -path temp/ory/keto/.bin \
        -o -path temp/ory/kratos/internal/client-go \
        -o -path temp/ory/kratos/test/e2e/mock/httptarget \
        -o -path temp/ossf/scorecard/tools \
        -o -path temp/prometheus/prometheus/internal/tools \
        -o -path temp/reddit/achilles-sdk/tools \
        -o -path temp/redpanda-data/connect/public/bundle \
        -o -path temp/samber/do/examples \
        -o -path temp/samber/do/http \
        -o -path temp/seaweedfs/seaweedfs/test/fuse_integration \
        -o -path temp/segmentio/encoding/benchmarks \
        -o -path temp/segmentio/encoding/proto/fixtures \
        -o -path temp/segmentio/stats/otlp \
        -o -path temp/sigstore/k8s-manifest-sigstore/example \
        -o -path temp/sigstore/rekor/hack/tools \
        -o -path temp/sigstore/sigstore/hack/tools \
        -o -path temp/snyk/policy-engine/pkg/input/schemas/tf/generate \
        -o -path temp/spf13/viper/remote \
        -o -path temp/spotify/confidence-sdk-go/demo \
        -o -path temp/swaggo/swag/example \
        -o -path temp/tailscale/tailscale/gokrazy/\*/builddir \
        -o -path temp/thomaspoignant/go-feature-flag/website/.ci \
        -o -path temp/uber-go/mock/bazel \
        -o -path temp/vektra/mockery/internal/fixtures/example_project/pkg_with_submodules \
        -o -path temp/vektra/mockery/tools \
        -o -path temp/wal-g/wal-g/internal/tools \
        \) -prune -o \
      -name go.mod -execdir $CMD $FLAGS ./... \; 2> "$LOG"
    # else echo "Skipping $i, $j pass..."
    fi
  done
done
