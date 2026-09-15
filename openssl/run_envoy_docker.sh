#!/bin/bash

set -x
set -euo pipefail

# Change to the top dir
cd "$(dirname "$0")/.."

# Build with libstdc++ rather than libc++ because the bssl-compat prefixer tool
# is linked against some of the LLVM libraries which require libstdc++
export ENVOY_STDLIB=libstdc++

# Tell the upstream run_envoy_docker.sh script to use our builder image
export ENVOY_BUILD_IMAGE=quay.io/jwendell/envoy-build-ubuntu@sha256:de2689a4c97657764e27050ffbee3c6330a81bf3cd52ede2a4efeff5bce86958
# Hand off to the upstream run_envoy_docker.sh script
exec ./ci/run_envoy_docker.sh "$@"
