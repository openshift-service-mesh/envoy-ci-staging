set -euo pipefail

ENVOY_DOCKER_BUILD_DIR=./my-build-dir/ ./openssl/run_envoy_docker.sh './ci/do_ci.sh dev //test/...'
