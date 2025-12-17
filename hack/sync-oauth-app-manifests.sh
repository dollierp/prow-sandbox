#!/bin/sh -efu

SELF_DIR=$(dirname "$(readlink -f "$0")")
TOP_DIR=${SELF_DIR%/*}
MANIFESTS_DIR=${TOP_DIR}/manifests/oauth-app

mkdir -p "${MANIFESTS_DIR}"

cd "${MANIFESTS_DIR}"

# https://github.com/kubernetes/test-infra/pull/36655
commit_before_removal='acd72a780ce88db59ffb1c2782e979a5a67934b2'

# The `git-archive` command does not work against GitHub repositories...
#git archive \
#  --format='tar.gz' \
#  --remote='https://github.com/kubernetes/test-infra.git' \
#  --verbose \
#  "${commit_before_removal}" config/prow/cluster \
#| tar -tzf -

# https://docs.github.com/en/repositories/working-with-files/using-files/downloading-source-code-archives#source-code-archive-urls
curl -gSL --fail-with-body https://github.com/kubernetes/test-infra/archive/"${commit_before_removal}".tar.gz \
| tar -xpzf - test-infra-"${commit_before_removal}"/config/prow/cluster \
    --exclude='build/*' \
    --exclude='prowjob-crd/*' \
    --exclude='starter/*' \
    --exclude='OWNERS' \
    --strip-components='4' \
    #--transform='s|^.*/||'

find . -type d -empty -printf '%P\0' | xargs -0r rmdir -pv

cd - >/dev/null

exit

# vi: set ft=sh et sw=4 ts=4:
