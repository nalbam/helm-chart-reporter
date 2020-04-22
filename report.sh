#!/bin/bash

SHELL_DIR=$(dirname $0)

DEFAULT="nalbam/charts-reporter"
REPOSITORY=${GITHUB_REPOSITORY:-$DEFAULT}

USERNAME=${GITHUB_ACTOR}
REPONAME=$(echo "${REPOSITORY}" | cut -d'/' -f2)

rm -rf ${SHELL_DIR}/target

mkdir -p ${SHELL_DIR}/target/previous
mkdir -p ${SHELL_DIR}/target/versions
mkdir -p ${SHELL_DIR}/target/release

TMP=/tmp/charts.json

_check_version() {
    CHART="$1"

    REPO="$(echo ${CHART} | cut -d'/' -f1)"
    NAME="$(echo ${CHART} | cut -d'/' -f2)"

    touch ${SHELL_DIR}/target/previous/${NAME}
    NOW="$(cat ${SHELL_DIR}/target/previous/${NAME} | xargs)"

    NEW="$(cat ${TMP} | CHART="https://hub.helm.sh/charts/${CHART}" jq '[.[] | select(.url==env.CHART)][0] | "\(.version) \(.app_version)"' -r | awk '{print $1" ("$2")"}')"

    printf '# %-40s %-25s %-25s\n' "${CHART}" "${NOW}" "${NEW}"

    printf "${NEW}" > ${SHELL_DIR}/target/versions/${NAME}

    if [ "${NOW}" == "${NEW}" ]; then
        return
    fi

    if [ -z "${SLACK_TOKEN}" ]; then
        return
    fi

    if [ "${REPO}" == "stable" ] || [ "${REPO}" == "incubator" ]; then
        FOOTER="<https://github.com/helm/charts/tree/master/${CHART}|${CHART}>"
    else
        FOOTER="${CHART}"
    fi

# cat <<EOF
    curl -sL opspresso.com/tools/slack | bash -s -- \
        --token="${SLACK_TOKEN}" --username="${REPONAME}" --color="good" \
        --footer="${FOOTER}" --footer_icon="https://repo.opspresso.com/favicon/helm-152.png" \
        --title="helm-chart updated" "\`${CHART}\`\n ${NOW} > ${NEW}"
# EOF

    echo " slack ${CHART} ${NOW} > ${NEW} "
    echo
}

# previous versions
VERSION=$(curl -s https://api.github.com/repos/${REPOSITORY}/releases/latest | grep tag_name | cut -d'"' -f4 | xargs)
if [ ! -z "${VERSION}" ]; then
    curl -sL https://github.com/${REPOSITORY}/releases/download/${VERSION}/versions.tar.gz | tar xz -C ${SHELL_DIR}/target/previous
fi

helm version

helm search hub -o json > ${TMP}

printf '# %-40s %-25s %-25s\n' "NAME" "NOW" "NEW"

# check versions
while read VAR; do
    _check_version ${VAR}
done < ${SHELL_DIR}/checklist.txt
echo

# package versions
pushd ${SHELL_DIR}/target/versions
tar -czf ../release/versions.tar.gz *
popd
