#!/bin/bash
set -euo pipefail

collect_logs() {
    if [[ -z "${TMT_TEST_DATA:-}" ]]; then
        return
    fi
    testlogs="${ENVOY_DOCKER_BUILD_DIR}/bazel_root/base/execroot/envoy/bazel-out/k8-fastbuild/testlogs"
    echo "Looking for testlogs in: ${testlogs}"
    if [[ -d "${testlogs}" ]]; then
        mkdir -p "${TMT_TEST_DATA}/testlogs"
        count=0
        while IFS= read -r xml; do
            if grep -q 'failures="[1-9]\|errors="[1-9]' "${xml}" 2>/dev/null; then
                reldir="${xml#"${testlogs}"/}"
                reldir="$(dirname "${reldir}")"
                mkdir -p "${TMT_TEST_DATA}/testlogs/${reldir}"
                cp "$(dirname "${xml}")/test.log" "${TMT_TEST_DATA}/testlogs/${reldir}/" 2>/dev/null && ((count++)) || true
            fi
        done < <(find "${testlogs}" -name "test.xml")
        echo "Collected ${count} failed test log(s) to ${TMT_TEST_DATA}/testlogs"
    else
        echo "WARNING: testlogs dir not found: ${testlogs}"
        echo "Contents of ${ENVOY_DOCKER_BUILD_DIR}:"
        ls -la "${ENVOY_DOCKER_BUILD_DIR}/" 2>/dev/null || true
        found=$(find "${ENVOY_DOCKER_BUILD_DIR}" -type d -name "testlogs" 2>/dev/null | head -3)
        if [[ -n "${found}" ]]; then
            echo "Found testlogs directories at: ${found}"
        fi
    fi
}

# Validate inputs (injected by build.yaml)
[[ "${SOURCE_REPO}" =~ ^https://github\.com/[a-zA-Z0-9_.\-]+/[a-zA-Z0-9_.\-]+\.git$ ]] \
    || { echo "bad SOURCE_REPO: ${SOURCE_REPO}" >&2; exit 1; }
[[ "${SOURCE_REF}" =~ ^[0-9a-f]{40}$ ]] \
    || { echo "bad SOURCE_REF: ${SOURCE_REF}" >&2; exit 1; }

echo "=== Machine specs ==="
grep -c ^processor /proc/cpuinfo || true
awk '/MemTotal/ {printf "%.0f GB\n", $2/1024/1024}' /proc/meminfo || true
df -h / /home /tmp 2>/dev/null | sort -u || true
echo "===================="

# Fresh clone of the PR source (like proxy's common.sh)
git clone "${SOURCE_REPO}" envoy-src
cd envoy-src
git checkout "${SOURCE_REF}"

mkdir -p build-dir
export SOURCE_DIR="$(pwd)"
export ENVOY_DOCKER_BUILD_DIR="$(pwd)/build-dir"

trap collect_logs EXIT

export BAZEL_BUILD_EXTRA_OPTIONS="--jobs=20 --local_resources=memory=HOST_RAM*.6"

# hotrestart_test: bazel sandbox Permission Denied on overlay2 inside Docker
# file_system_buffer: async file I/O times out with HTTP/2 upstream; filter is upstream wip
EXCLUDED_TESTS="-//test/integration:hotrestart_test -//test/extensions/filters/http/file_system_buffer:file_system_buffer_integration_test"
# ssl_socket_test:
#   ClientSessionResumption*: OpenSSL delivers Connected events in different order than
#     BoringSSL, deadlocking InSequence mock expectations in testClientSessionResumption
export BAZEL_EXTRA_TEST_OPTIONS="--test_env=GTEST_FILTER=-SslSocketTest.ClientSessionResumptionEnabledTls12:SslSocketTest.ClientSessionResumptionEnabledTls13"

echo "=== Disk before build ==="
df -h / /home /tmp 2>/dev/null | sort -u || true
echo "========================="

rc=0
./openssl/run_envoy_docker.sh "./ci/do_ci.sh dev //test/... -- ${EXCLUDED_TESTS}" || rc=$?

echo "=== Disk after build ==="
df -h / /home /tmp 2>/dev/null | sort -u || true
echo "========================"

exit "${rc}"
