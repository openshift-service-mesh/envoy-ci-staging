#!/bin/bash
set -euo pipefail

# Validate inputs (injected by build.yaml)
[[ "${SOURCE_REPO}" =~ ^https://github\.com/[a-zA-Z0-9_.\-]+/[a-zA-Z0-9_.\-]+\.git$ ]] \
    || { echo "bad SOURCE_REPO: ${SOURCE_REPO}" >&2; exit 1; }
[[ "${SOURCE_REF}" =~ ^[0-9a-f]{40}$ ]] \
    || { echo "bad SOURCE_REF: ${SOURCE_REF}" >&2; exit 1; }

# Fresh clone of the PR source (like proxy's common.sh)
git clone "${SOURCE_REPO}" envoy-src
cd envoy-src
git checkout "${SOURCE_REF}"

sudo sysctl -w user.max_user_namespaces=15000 >/dev/null
mkdir -p build-dir
sudo chcon -R -t container_file_t "$(pwd)" 2>/dev/null || true
export SOURCE_DIR="$(pwd)"
export ENVOY_DOCKER_BUILD_DIR="$(pwd)/build-dir"

rc=0
./openssl/run_envoy_docker.sh './ci/do_ci.sh dev //test/...' || rc=$?

# podman-compose exit-code propagation is unreliable; require the binary.
if [[ ${rc} -eq 0 && ! -x bazel-bin/source/exe/envoy-static ]]; then
    echo "ERROR: envoy-static missing despite successful exit" >&2
    rc=1
fi

exit "${rc}"
