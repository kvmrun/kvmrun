#!/bin/bash
set -eu

declare -rx GOOS="linux"
declare -rx GOARCH="amd64"
declare -rx GOBIN="$(pwd)/bin"

declare -r USER_GROUP="$(stat --printf "%u:%g" .)"

install -d "$GOBIN"
trap "chown -R $USER_GROUP $GOBIN" 0

go version

go fmt "./..."

go install \
    -v \
    -buildvcs=false \
    -ldflags "-s -w" \
        "./cmd/kvmrund" \
        "./cmd/vmm" \
        "./cmd/launcher" \
        "./cmd/gencert" \
        "./cmd/printpci" \
        "./cmd/update-kvmrun-package"

go install \
    -v \
    -buildvcs=false \
    -buildmode=pie \
    -tags 'netgo,osusergo' \
    -ldflags "-s -w -linkmode external -extldflags -static-pie" \
        "./cmd/netinit" \
        "./cmd/vnetctl"

exit 0
