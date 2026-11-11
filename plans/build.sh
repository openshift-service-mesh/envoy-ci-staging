#!/bin/bash
set -euo pipefail

# Testing Farm checks out the PR *base* branch; fetch and checkout the PR head
# instead. SOURCE_REPO/SOURCE_REF are injected by build.yaml (validated there).
if [[ -n "${SOURCE_REPO:-}" && -n "${SOURCE_REF:-}" ]]; then
    [[ "${SOURCE_REPO}" =~ ^https://github\.com/[a-zA-Z0-9_.\-]+/[a-zA-Z0-9_.\-]+\.git$ ]] \
        || { echo "bad SOURCE_REPO: ${SOURCE_REPO}" >&2; exit 1; }
    [[ "${SOURCE_REF}" =~ ^[0-9a-f]{40}$ ]] || { echo "bad SOURCE_REF: ${SOURCE_REF}" >&2; exit 1; }
    git remote add pr-source "${SOURCE_REPO}" 2>/dev/null || true
    git fetch pr-source "${SOURCE_REF}" 2>/dev/null || git fetch pr-source
    git checkout --detach "${SOURCE_REF}"
fi

# Guest-side prep for the standard chain (openssl/run_envoy_docker.sh ->
# ci/run_envoy_docker.sh -> docker compose, provided by the podman shims
# installed in the prepare step). The build runs ONLINE: bazel fetches
# dependencies during the build, so no hermetic/network-disconnect phase.
sysctl -w user.max_user_namespaces=15000 >/dev/null # bazel sandboxing
mkdir -p build-dir
chcon -R -t container_file_t "$(pwd)" 2>/dev/null || true # SELinux; compose mounts lack :z
export SOURCE_DIR="$(pwd)" # absolute paths for the compose volumes
export ENVOY_DOCKER_BUILD_DIR="$(pwd)/build-dir"

rc=0
./openssl/run_envoy_docker.sh './ci/do_ci.sh dev //test/...' || rc=$?

# podman-compose exit-code propagation is unreliable; require the binary.
if [[ ${rc} -eq 0 && ! -x bazel-bin/source/exe/envoy-static ]]; then
    echo "ERROR: envoy-static missing despite successful exit" >&2
    rc=1
fi

exit "${rc}"
