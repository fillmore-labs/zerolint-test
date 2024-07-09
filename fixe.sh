#!/usr/bin/env bash

dir_list_file="dirs.txt"

if [ ! -r "$dir_list_file" ]; then
    echo "Error: Directory list file not found: $dir_list_file"
    exit 1
fi

GOBIN="$(go env GOPATH)/bin"
GO124BIN="$(env GO111MODULE=off $GOBIN/go1.24.9 env GOROOT)/bin"

ERRORTYPE="$(which errortype)"
if [ -z "$ERRORTYPE" ]; then
  go install fillmore-labs.com/errortype@latest
  ERRORTYPE="$GOBIN/errortype"
fi
[ -x "$ERRORTYPE" ] || exit 1

WIRE="$(which wire)"
if [ -z "$WIRE" ]; then
  go install github.com/google/wire/cmd/wire@latest
  WIRE="$GOBIN/wire"
fi
[ -x "$WIRE" ] || exit 1

MOCKGEN="$(which mockgen)"
if [ -z "$MOCKGEN" ]; then
  go install go.uber.org/mock/mockgen@latest
  MOCKGEN="$GOBIN/mockgen"
fi
[ -x "$MOCKGEN" ] || exit 1

go env -w CC=cc CXX=c++ CGO_ENABLED=1 GOEXPERIMENT=

OVERRIDES="$(pwd)/overrides"
LOGS="$(pwd)/logs"

mkdir -p "$LOGS" "$OVERRIDES"

for i in temp/*/*; do
  if [ ! -d $i ]; then
    echo "run ./prepare.sh first"
    exit 1
  fi
  I="$(echo $i | sed -e 's#^temp/\([^/]*\)/\([^/]*\)$#\1_\2#')"
  IGNORE=
  case $i in
    temp/wal-g/wal-g)
      if [ ! -r "/usr/include/sodium.h" ]; then
        IGNORE=true
      fi
      ;;
      # 
    temp/dolthub/dolt|temp/dolthub/doltgresql)
      if [ ! -r "/usr/include/unicode/uregex.h" ]; then
        IGNORE=true
      fi
      ;;
    temp/ovh/venom)
      if [ ! -r "/usr/include/sql.h" ]; then
        IGNORE=true
      fi
      ;;
    temp/element-hq/dendrite|temp/mautrix/whatsapp)
      if [ ! -d "/usr/include/olm" ]; then
        IGNORE=true
      fi
      ;;
    temp/projectcalico/calico)
      if [ ! -d "/usr/include/bpf" ]; then
        IGNORE=true
      fi
      ;;
    temp/unikraft/kraftkit)
      if [ ! -d "/usr/include/btrfs" ]; then
        IGNORE=true
      fi
      ;;
  esac
  FIRST=true
  for j in errortype errordebug ; do
    LOG="$LOGS/${I}_$j.log"
    OVERRIDE="$OVERRIDES/${I}.yaml"
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
          temp/woodpecker-ci/woodpecker)
            mkdir -p "$i/web/dist" && touch "$i/web/dist/empty"
            ;;
          temp/google/go-cloud|temp/apache/doris|temp/at-wat/mqtt-go)
            find "$i"/*/ -name go.mod -execdir go mod tidy \;
            ;;
          temp/grafana/grafana)
            if [ ! -e "$i/pkg/server/wire_gen.go" ]; then
              (cd "$i" && "$WIRE" gen -tags oss ./pkg/server)
            fi
            ;;
          temp/Netflix/chaosmonkey|\
          temp/apache/skywalking-banyandb|\
          temp/bazelbuild/bazelisk|\
          temp/go-yaml/yaml|\
          temp/google/mangle|\
          temp/nats-io/nats.go|\
          temp/redpanda-data/connect|\
          temp/segmentio/kafka-go)
            (cd "$i" && go mod tidy)
            ;;
          temp/DataDog/datadog-agent)
            (cd "$i" && go work edit -dropgodebug=tlskyber)
            ;;
          temp/aerospike/aerospike-management-lib)
            (cd "$i" && \
              "$MOCKGEN" --source info/as_parser.go --destination info/as_parser_mock.go --package info && \
              "$MOCKGEN" --source asconfig/generate.go --destination asconfig/generate_mock.go --package asconfig && \
              "$MOCKGEN" --source deployment/deployment.go --destination deployment/deployment_mock.go --package deployment )
            ;;
          temp/open-feature/go-sdk)
            (cd "$i" && \
              "$MOCKGEN" -source=openfeature/provider.go -destination=openfeature/provider_mock.go -package=openfeature && \
              "$MOCKGEN" -source=openfeature/hooks.go -destination=openfeature/hooks_mock.go -package=openfeature && \
              "$MOCKGEN" -source=openfeature/interfaces.go -destination=openfeature/interfaces_mock.go -package=openfeature )
            ;;
          temp/aaPanel/BillionMail)
            (cd "$i/core" && go mod tidy)
            ;;
          temp/GoogleCloudPlatform/grpc-gcp-go)
            (cd "$i/cloudprober" && go mod tidy)
            ;;
          temp/envoyproxy/go-control-plane)
            (cd "$i/envoy" && go mod tidy)
            ;;
          temp/qingstor/qingstor-sdk-go)
            (cd "$i"/test && go mod tidy)
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
        temp/Azure/azure-service-operator|\
        temp/googleapis/google-api-go-client|\
        temp/grafana/alloy|\
        temp/grafana/grafana|\
        temp/gravitational/teleport|\
        temp/hashicorp/vault|\
        temp/influxdata/telegraf|\
        temp/pingcap/tidb)
          CMD="go vet -vettool=$ERRORTYPE"
          ;;
        temp/syncthing/syncthing)
          CMD="go vet -vettool=$ERRORTYPE -tags=noassets"
          ;;
        temp/dapr/dapr|\
        temp/dapr/kit)
          CMD="go vet -vettool=$ERRORTYPE -tags=unit"
          ;;
        temp/k8snetworkplumbingwg/whereabouts|\
        temp/woodpecker-ci/woodpecker)
          CMD="go vet -vettool=$ERRORTYPE -tags=test"
          ;;
        temp/pingcap/ticdc|\
        temp/samber/lo|\
        temp/slimtoolkit/slim)
          CMD="$ERRORTYPE -test=false"
          ;;
        temp/osmosis-labs/osmosis)
          CMD="env PATH=$GO124BIN:$PATH $ERRORTYPE -test=false"
          ;;
        temp/cloudflare/circl|\
        temp/cosmos/cosmos-sdk|\
        temp/cosmos/gaia|\
        temp/cosmos/ibc-go|\
        temp/daixiang0/gci|\
        temp/ent/ent|\
        temp/ezpkg/ezpkg|\
        temp/go-swagger/go-swagger|\
        temp/golang/tools|\
        temp/gotestyourself/gotest.tools|\
        temp/hugelgupf/p9|\
        temp/klauspost/compress|\
        temp/modelcontextprotocol/go-sdk|\
        temp/oapi-codegen/oapi-codegen|\
        temp/prometheus/client_golang|\
        temp/quasilyte/go-ruleguard|\
        temp/siderolabs/discovery-service|\
        temp/siderolabs/sidero|\
        temp/siderolabs/talos|\
        temp/sourcegraph/scip|\
        temp/superfly/fly-go|\
        temp/yarpc/yarpc-go)
          CMD="env PATH=$GO124BIN:$PATH $ERRORTYPE"
          ;;
        temp/aquasecurity/trivy)
          CMD="env GOEXPERIMENT=jsonv2 $ERRORTYPE"
          ;;
        *)
          CMD="$ERRORTYPE"
          ;;
      esac
      case $j in
        errortype)
          FLAGS="-c=0 -style-check=false"
          ;;
        errordebug)
          FLAGS="-c=0 -check-is=false -deep-is-check -unchecked-assert -check-unused -tracetypes=.* -suggest=$OVERRIDE.new"
          ;;
      esac
      if [ -e "$OVERRIDE" ]; then
        FLAGS="$FLAGS -overrides=$OVERRIDE"
      fi
      echo "Running errortype on $i, $j pass..."
      NOFILES=true
      while IFS= read -r dir_path; do
          if [ -z "$dir_path" ] || [[ "$dir_path" =~ ^# ]]; then
              continue
          fi

          if [[ "$dir_path" == "$i" || "$dir_path" == "$i/"* ]]; then
              if [ -d "$dir_path" ]; then
                  NOFILES=false
                  pushd "$dir_path" > /dev/null
                  $CMD $FLAGS ./... 2>> "$LOG"
                  EXIT_CODE=$?
                  popd > /dev/null

                  if [ $EXIT_CODE -ne 0 ]; then
                    echo "error $EXIT_CODE in $dir_path"
                    echo "last error $EXIT_CODE in $dir_path" >> "$LOG"
                  fi
              else
                  echo "Warning: Matching path is not a directory: '$dir_path'"
              fi
          fi
      done < "$dir_list_file"
      if $NOFILES; then
        echo ">>> No files in $i, $j, candidates:"
        find "$i" -name go.mod | sed -Ee 's#/go\.mod$##'
      fi
    # else echo "Skipping $i, $j pass..."
    fi
  done
done
