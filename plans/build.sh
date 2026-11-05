#!/bin/bash
set -euo pipefail

# Fetch and checkout the PR code when running in CI (SOURCE_REPO/SOURCE_REF
# are injected by the Testing Farm action). Skipped for direct local runs.
if [[ -n "${SOURCE_REPO:-}" && -n "${SOURCE_REF:-}" ]]; then
    if ! git rev-parse --verify "${SOURCE_REF}^{commit}" &>/dev/null; then
        git remote add pr-source "${SOURCE_REPO}" 2>/dev/null || true
        git fetch pr-source
    fi
    git checkout "${SOURCE_REF}"
fi

ENVOY_DOCKER_BUILD_DIR="${ENVOY_DOCKER_BUILD_DIR:-./build-dir/}" \
    ./openssl/run_envoy_docker.sh './ci/do_ci.sh dev //test/...'
