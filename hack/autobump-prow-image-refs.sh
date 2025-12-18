#!/bin/sh -efu

# See documentation:
# - https://docs.prow.k8s.io/docs/components/cli-tools/generic-autobumper/
#
# See implementation:
# - https://sigs.k8s.io/prow/cmd/generic-autobumper/main.go#main()
#   └─https://sigs.k8s.io/prow/cmd/generic-autobumper/bumper/bumper.go#Run()
#     └─processGitHub()
#       └─MinimalGitPush()

SELF_DIR=$(dirname "$(readlink -f "$0")")
TOP_DIR=${SELF_DIR%/*}

cd "${TOP_DIR}"

# https://www.redhat.com/blog/podman-kubernetes-secrets
podman secret create --env github-token GITHUB_TOKEN

# Function invocations via trap are not figured out
# shellcheck disable=2329  # https://www.shellcheck.net/wiki/SC2329
at_exit()
{
    podman secret exists github-token \
    && podman secret rm github-token

    git remote show bumper-fork-remote >/dev/null 2>&1 \
    && git remote remove bumper-fork-remote
}
trap 'set +e -x; at_exit' EXIT

GITHUB_WHOAMI=$(
  curl -qgsSL --fail-with-body https://api.github.com/user \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H 'Accept: application/vnd.github+json'
)

eval GIT_COMMITTER_NAME="$(
  printf '%s\n' "${GITHUB_WHOAMI}" \
  | awk -F ',' '{
      for (i = 1; i <= NF; i++)
        if ($i ~ "\"name\":") {
          FS=":"; $0 = $i
          gsub("(^ +| +$)", "", $NF);
          print($NF); exit
        }
    }'
)"

eval GIT_COMMITTER_EMAIL="$(
  printf '%s\n' "${GITHUB_WHOAMI}" \
  | awk -F ',' '{
      for (i = 1; i <= NF; i++)
        if ($i ~ "\"email\":") {
          FS=":"; $0 = $i
          gsub("(^ +| +$)", "", $NF);
          print($NF); exit
        }
    }'
)"

podman container run --rm \
  --env=GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME}" \
  --env=GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL}" \
  --secret='github-token' \
  --security-opt=label='disable' \
  --userns='keep-id' \
  --volume="${TOP_DIR}:/workspace" \
  --workdir='/workspace' \
  us-docker.pkg.dev/k8s-infra-prow/images/generic-autobumper:latest \
  --config='/workspace/config/autobump-prow-image-refs.yaml' \
  --skip-pullrequest \
  "$@"

cd - >/dev/null

exit

# vi: set ft=sh et sw=4 ts=4:
