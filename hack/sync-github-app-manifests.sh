#!/bin/sh -efu

SELF_DIR=$(dirname "$(readlink -f "$0")")
TOP_DIR=${SELF_DIR%/*}
MANIFESTS_DIR=${TOP_DIR}/manifests/github-app
PROW_NAMESPACE='prow'

mkdir -p "${MANIFESTS_DIR}"

cd "${MANIFESTS_DIR}"

curl -gSL --fail-with-body 'https://github.com/kubernetes-sigs/prow/raw/main/config/prow/cluster/starter/starter-gcs.yaml' \
| csplit - '/^---$/' '{*}' \
    --prefix='' \
    --suffix-format='%02d-prow-manifest.yaml' \
    --elide-empty-files \
    --quiet

find . -maxdepth 1 -type f -name '*-prow-manifest.yaml' \
| while IFS='' read -r raw_manifest; do
    kind=$(awk '/^kind: / { print(tolower($NF)) }' "${raw_manifest}")

    if [ ! "${kind}" ]; then
        rm -v "${raw_manifest}"
        continue
    fi

    name=$(
      awk '
        BEGIN{ metadata = 0 }
        /^metadata:$/ { metadata = 1; next }
        /^  name: / && metadata { gsub("(^\"|\"$)", "", $NF); print($NF) ; exit }
      ' "${raw_manifest}"
    )

    namespace=$(
      awk -v prow_namespace="${PROW_NAMESPACE}" '
        BEGIN{ metadata = 0; namespace = "" }
        /^metadata:$/ { metadata = 1; next }
        /^  namespace: / && metadata {
          namespace = $NF
          gsub("(^\"|\"$)", "", namespace); gsub("-", "_", namespace)
          exit
        }
        END{ print(namespace == "" ? prow_namespace : namespace) }
      ' "${raw_manifest}"
    )

    manifest=${name}_${kind}
    if [ "${namespace}" != "${PROW_NAMESPACE}" ]; then
        manifest=${manifest}_${namespace}
    fi

    # Ensure YAML files use a Document Start Marker
    sed -e '1 { /^---$/ ! s|^|---\n| }' \
      "${raw_manifest}" >"${manifest}".yaml

    rm -f "${raw_manifest}"
done

cd - >/dev/null

exit

# vi: set ft=sh et sw=4 ts=4:
