#!/bin/bash

set -x
set -euo pipefail

# Change to the top dir
cd "$(dirname "$0")/.."

# Build with libstdc++ rather than libc++ because the bssl-compat prefixer tool
# is linked against some of the LLVM libraries which require libstdc++
export ENVOY_STDLIB=libstdc++

# Tell the upstream run_envoy_docker.sh script to use our builder image
# (the same pinned image the Testing Farm CI uses, see plans/build.sh)
export ENVOY_BUILD_IMAGE="$(cat openssl/builder-image)"
# Hand off to the upstream run_envoy_docker.sh script
exec ./ci/run_envoy_docker.sh "$@"
