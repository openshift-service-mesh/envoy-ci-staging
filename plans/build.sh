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

mkdir -p build-dir
export SOURCE_DIR="$(pwd)"
export ENVOY_DOCKER_BUILD_DIR="$(pwd)/build-dir"

rc=0
./openssl/run_envoy_docker.sh './ci/do_ci.sh dev //test/...' || rc=$?

# Collect failed test logs for TF artifacts
if [[ -n "${TMT_TEST_DATA:-}" ]]; then
    testlogs="${ENVOY_DOCKER_BUILD_DIR}/bazel_root/base/execroot/envoy/bazel-out/k8-fastbuild/testlogs"
    if [[ -d "${testlogs}" ]]; then
        mkdir -p "${TMT_TEST_DATA}/testlogs"
        while IFS= read -r xml; do
            if grep -q 'failures="[1-9]\|errors="[1-9]' "${xml}" 2>/dev/null; then
                dir="$(dirname "${xml}")"
                find "${dir}" -name "test.log" -exec cp --parents {} "${TMT_TEST_DATA}/testlogs/" \;
            fi
        done < <(find "${testlogs}" -name "test.xml")
    fi
fi

if [[ ${rc} -eq 0 && ! -x bazel-bin/source/exe/envoy-static ]]; then
    echo "ERROR: envoy-static missing despite successful exit" >&2
    rc=1
fi

exit "${rc}"
