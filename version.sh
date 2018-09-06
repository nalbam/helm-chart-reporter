#!/bin/bash

SHELL_DIR=$(dirname $0)

USERNAME=${1:-nalbam}
REPONAME=${2:-helm-chart-reporter}
GITHUB_TOKEN=${3}
SLACK_TOKEN=${4}

CHANGED=

git config --global user.name "bot"
git config --global user.email "ops@nalbam.com"

helm init --client-only

get_version() {
    NAME=$1

    mkdir -p ${SHELL_DIR}/versions
    touch ${SHELL_DIR}/versions/${NAME}

    NOW=$(cat ${SHELL_DIR}/versions/${NAME} | xargs)
    NEW=$(helm search "stable/${NAME}" | grep "stable/${NAME}" | head -1 | awk '{print $2}' | xargs)

    printf '# %-25s %-10s %-10s\n' "${NAME}" "${NOW}" "${NEW}"

    if [ "x${NOW}" != "x${NEW}" ]; then
        CHANGED=true

        printf "${NEW}" > ${SHELL_DIR}/versions/${NAME}

        # if [ ! -z ${SLACK_TOKEN} ]; then
        #     curl -sL toast.sh/helper/slack.sh | bash -s -- --token="${SLACK_TOKEN}" \
        #         --color="good" --title="helm chart updated" ${NAME} ${NEW}
        # fi

        if [ ! -z ${GITHUB_TOKEN} ]; then
            git add --all
            git commit -m "${NAME} ${NEW}"
        fi
    fi
}

get_version chartmuseum
get_version cluster-autoscaler
get_version docker-registry
get_version efs-provisioner
get_version grafana
get_version heapster
get_version jenkins
get_version kubernetes-dashboard
get_version metrics-server
get_version nginx-ingress
get_version prometheus
get_version sonarqube
get_version sonatype-nexus

if [ ! -z ${CHANGED} ] && [ ! -z ${GITHUB_TOKEN} ]; then
    echo "# git push github.com/${USERNAME}/${REPONAME}"
    git push -q https://${GITHUB_TOKEN}@github.com/${USERNAME}/${REPONAME}.git master
fi
