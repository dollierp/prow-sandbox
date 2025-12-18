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

if [ ! "${GIT_COMMITTER_NAME-}" ]; then
    GITHUB_WHOAMI=$(
      wget -qO- https://api.github.com/user \
        --header "Authorization: Bearer ${GITHUB_TOKEN}" \
        --header 'Accept: application/vnd.github+json'
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
fi

export GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

if [[ -z "${container-}" ]]; then
    # https://www.redhat.com/blog/podman-kubernetes-secrets
    podman secret create --env github-token GITHUB_TOKEN

    generic_autobumper()
    (
        set -x
        podman container run --rm \
          --env='GIT_COMMITTER_NAME' \
          --env='GIT_COMMITTER_EMAIL' \
          --secret='github-token' \
          --cap-drop='ALL' \
          --security-opt='label=disable' \
          --security-opt='no-new-privileges' \
          --userns='keep-id' \
          --volume="${TOP_DIR}:/workspace" \
          --workdir='/workspace' \
          us-docker.pkg.dev/k8s-infra-prow/images/generic-autobumper:latest \
          "$@"

    )
else
    generic_autobumper()( set -x; generic-autobumper "$@" )
fi

# Function invocations via trap are not figured out
# shellcheck disable=2329  # https://www.shellcheck.net/wiki/SC2329
at_exit()
{
    if [ -z "${container-}" ]; then
        podman secret exists github-token \
        && podman secret rm github-token
    fi

    git remote show bumper-fork-remote >/dev/null 2>&1 \
    && git remote remove bumper-fork-remote
}
trap 'set +e -x; at_exit' EXIT

generic_autobumper \
  --config='./config/autobump-prow-image-refs.yaml' \
  --skip-pullrequest \
  "$@"

git show --stat

cd - >/dev/null

exit

# vi: set ft=sh et sw=4 ts=4:
