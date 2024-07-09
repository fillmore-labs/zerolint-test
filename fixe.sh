#!/usr/bin/env bash

dir_list_file="dirs.txt"

if [ ! -r "$dir_list_file" ]; then
    echo "Error: Directory list file not found: $dir_list_file"
    exit 1
fi

ERRORTYPE="$(which errortype)"
if [ -z "$ERRORTYPE" ]; then
  go install fillmore-labs.com/errortype@latest
  ERRORTYPE="$(go env GOPATH)/bin/errortype"
fi
[ -x "$ERRORTYPE" ] || exit 1

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
          temp/google/go-cloud)
            find "$i"/*/ -name go.mod -execdir go mod tidy \;
            ;;
          temp/grafana/grafana)
            if [ ! -e "$i/pkg/server/wire_gen.go" ]; then
              (cd "$i" && "$WIRE" gen -tags oss ./pkg/server)
            fi
            ;;
          temp/bazelbuild/bazelisk|temp/nats-io/nats.go|temp/go-yaml/yaml|temp/redpanda-data/connect|temp/segmentio/kafka-go|temp/Netflix/chaosmonkey)
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
        temp/dapr/dapr|temp/dapr/kit)
          CMD="$ERRORTYPE -tags=unit"
          ;;
        temp/k8snetworkplumbingwg/whereabouts)
          CMD="$ERRORTYPE -tags=test"
          ;;
        temp/grafana/alloy|temp/grafana/grafana|temp/gravitational/teleport|temp/hashicorp/vault)
          CMD="env GOMEMLIMIT=8000MiB $ERRORTYPE"
          ;;
        temp/Azure/azure-service-operator|temp/pingcap/tidb)
          CMD="go vet -vettool=$ERRORTYPE"
          ;;
        temp/syncthing/syncthing)
          CMD="$ERRORTYPE -tags=noassets"
          ;;
        temp/pingcap/ticdc)
          CMD="$ERRORTYPE -test=false"
          ;;
        *)
          CMD="$ERRORTYPE"
          ;;
      esac
      case $j in
        errortype)
          FLAGS="-c=0 -stylecheck=false"
          ;;
        errordebug)
          FLAGS="-c=0 -check-is=false -deep-is-check -unchecked-assert -trace -suggest=$OVERRIDE.new"
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
                  if [ $? -ne 0 ]; then
                    echo "error in $dir_path"
                    echo "last error in $dir_path" >> "$LOG"
                  fi
                  popd > /dev/null
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
