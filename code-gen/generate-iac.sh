#!/bin/bash

########################################################################################################################
#
# This script may be used to generate the initial Kubernetes configurations to push into the cluster-state repository
# for a particular tenant. This repo is referred to as the cluster state repo because the EKS clusters are always
# (within a few minutes) reflective of the code in this repo. This repo is the only interface for updates to the
# clusters. In other words, kubectl commands that alter the state of the cluster are verboten outside of this repo.
#
# The intended audience of this repo is primarily the Ping Professional Services and Support team, with limited access
# granted to Customer administrators. These users may further tweak the cluster state per the tenant's requirements.
# They are expected to have an understanding of Kubernetes manifest files and kustomize, a client-side tool used to make
# further customizations to the initial state generated by this script.
#
# The script generates Kubernetes manifest files for 4 different environments - dev, test, staging and prod. The
# manifest files for these environments contain deployments of both the Ping Cloud stack and the supporting tools
# necessary to provide an end-to-end solution.
#
# ------------
# Requirements
# ------------
# The script requires the following tools to be installed:
#   - openssl
#   - ssh-keygen
#   - base64
#   - kustomize
#   - envsubst
#
# ------------------
# Usage instructions
# ------------------
# The script does not take any parameters, but rather acts on environment variables. The environment variables will
# be substituted into the variables in the yaml template files. The following mandatory environment variables must be
# present before running this script:
#
# ----------------------------------------------------------------------------------------------------------------------
# Variable                    | Purpose
# ----------------------------------------------------------------------------------------------------------------------
# PING_IDENTITY_DEVOPS_USER   | A user with license to run Ping Software
# PING_IDENTITY_DEVOPS_KEY    | The key to the above user
#
# In addition, the following environment variables, if present, will be used for the following purposes:
#
# ----------------------------------------------------------------------------------------------------------------------
# Variable               | Purpose                                            | Default (if not present)
# ----------------------------------------------------------------------------------------------------------------------
# TENANT_NAME            | The name of the tenant, e.g. k8s-icecream. This    | PingPOC
#                        | will be used to interpret the Kubernetes cluster   |
#                        | for the different CDEs. For example, for the       |
#                        | above tenant name, the Kubernetes clusters for     |
#                        | the various CDEs are assumed to be                 |
#                        | k8s-icecream-prod, k8s-icecream-staging,           |
#                        | k8s-icecream-dev and k8s-icecream-test. For        |
#                        | PCPT, the cluster name is a required parameter     |
#                        | to Container Insights, an AWS-specific logging     |
#                        | and monitoring solution.                           |
#                        |                                                    |
# TENANT_DOMAIN          | The tenant's domain, e.g. k8s-icecream.com         | eks-poc.au1.ping-lab.cloud
#                        |                                                    |
# REGION                 | The region where the tenant environment is         | us-east-2
#                        | deployed. For PCPT, this is a required parameter   |
#                        | to Container Insights, an AWS-specific logging     |
#                        | and monitoring solution.                           |
#                        |                                                    |
# SIZE                   | Size of the environment, which pertains to the     | small
#                        | number of user identities. Legal values are        |
#                        | small, medium or large.                            |
#                        |                                                    |
# CLUSTER_STATE_REPO_URL | The URL of the cluster-state repo                  | https://github.com/pingidentity/ping-cloud-base
#                        |                                                    |
# CONFIG_REPO_URL        | The URL of the config repo                         | https://github.com/pingidentity/pingidentity-server-profiles
#                        |                                                    |
# CONFIG_REPO_BRANCH     | The branch within the config repo to use for       | pcpt
#                        | application configuration                          |
#                        |                                                    |
# ARTIFACT_REPO_URL      | The URL for plugins (e.g. PF kits, PD extensions). | No default
#                        | For PCPT, this is an S3 bucket. If not provided,   |
#                        | the Ping stack will be provisioned without         |
#                        | plugins.                                           |
#                        |                                                    |
# LOG_ARCHIVE_URL        | The URL of the log archives. If provided, logs are | No default
#                        | periodically captured and sent to this URL.        |
#                        |                                                    |
# K8S_GIT_URL            | The Git URL for the Kubernetes base manifest files | https://github.com/pingidentity/ping-cloud-base
#                        |                                                    |
# K8S_GIT_BRANCH         | The Git branch within the above Git URL            | master
#                        |                                                    |
# REGISTRY_NAME          | The registry hostname for the Docker images used   | docker.io
#                        | by the Ping stack. This can be Docker hub, ECR     |
#                        | (1111111111.dkr.ecr.us-east-2.amazonaws.com), etc. |
########################################################################################################################

########################################################################################################################
# Substitute variables in all template files in the provided directory.
#
# Arguments
#   ${1} -> The directory that contains the template files.
########################################################################################################################

# The list of variables in the template files that will be substituted.
VARS='${PING_IDENTITY_DEVOPS_USER_BASE64}
${PING_IDENTITY_DEVOPS_KEY_BASE64}
${TENANT_DOMAIN}
${REGION}
${SIZE}
${CLUSTER_NAME}
${CLUSTER_STATE_REPO_URL}
${CLUSTER_STATE_REPO_HOST}
${CONFIG_REPO_URL}
${CONFIG_REPO_BRANCH}
${ARTIFACT_REPO_URL}
${LOG_ARCHIVE_URL}
${K8S_GIT_URL}
${K8S_GIT_BRANCH}
${REGISTRY_NAME}
${TLS_CRT_BASE64}
${TLS_KEY_BASE64}
${IDENTITY_PUB}
${IDENTITY_KEY}
${ENVIRONMENT}
${ENVIRONMENT_GIT_PATH}
${KUSTOMIZE_BASE}'

substitute_vars() {
  SUBST_DIR=${1}
  for FILE in $(find "${SUBST_DIR}" -type f); do
    EXTENSION="${FILE##*.}"
    if test "${EXTENSION}" = 'tmpl'; then
      TARGET_FILE="${FILE%.*}"
      envsubst "${VARS}" < "${FILE}" > "${TARGET_FILE}"
      rm -f "${FILE}"
    fi
  done
}

# Source some utility methods.
. ../utils.sh

# Checking required tools and environment variables.
HAS_REQUIRED_TOOLS=$(check_binaries "openssl" "ssh-keygen" "base64" "kustomize" "envsubst"; echo ${?})
HAS_REQUIRED_VARS=$(check_env_vars "PING_IDENTITY_DEVOPS_USER" "PING_IDENTITY_DEVOPS_KEY"; echo ${?})

if test ${HAS_REQUIRED_TOOLS} -ne 0 || test ${HAS_REQUIRED_VARS} -ne 0; then
  exit 1
fi

# Print out the values provided used for each variable.
echo "Initial SIZE: ${SIZE}"
echo "Initial TENANT_NAME: ${TENANT_NAME}"
echo "Initial TENANT_DOMAIN: ${TENANT_DOMAIN}"
echo "Initial REGION: ${REGION}"

echo "Initial CLUSTER_STATE_REPO_URL: ${CLUSTER_STATE_REPO_URL}"
echo "Initial CLUSTER_STATE_REPO_HOST: ${CLUSTER_STATE_REPO_HOST}"

echo "Initial CONFIG_REPO_URL: ${CONFIG_REPO_URL}"
echo "Initial CONFIG_REPO_BRANCH: ${CONFIG_REPO_BRANCH}"

echo "Initial ARTIFACT_REPO_URL: ${ARTIFACT_REPO_URL}"
echo "Initial LOG_ARCHIVE_URL: ${LOG_ARCHIVE_URL}"

echo "Initial K8S_GIT_URL: ${K8S_GIT_URL}"
echo "Initial K8S_GIT_BRANCH: ${K8S_GIT_BRANCH}"

echo "Initial REGISTRY_NAME: ${REGISTRY_NAME}"
echo ---

# Use defaults for other variables, if not present.
export SIZE="${SIZE:-small}"
export TENANT_NAME="${TENANT_NAME:-PingPOC}"
export TENANT_DOMAIN="${TENANT_DOMAIN:-eks-poc.au1.ping-lab.cloud}"
export REGION="${REGION:-us-east-2}"

export CLUSTER_STATE_REPO_URL="${CLUSTER_STATE_REPO_URL:-git@github.com:pingidentity/ping-cloud-base.git}"
export CLUSTER_STATE_REPO_HOST=$(cut -d '@' -f 2 <<< ${CLUSTER_STATE_REPO_URL} | cut -d '/' -f 1)

export CONFIG_REPO_URL="${CONFIG_REPO_URL:-https://github.com/pingidentity/pingidentity-server-profiles}"
export CONFIG_REPO_BRANCH="${CONFIG_REPO_BRANCH:-pcpt}"

export ARTIFACT_REPO_URL="${ARTIFACT_REPO_URL}"
export LOG_ARCHIVE_URL="${LOG_ARCHIVE_URL}"

export K8S_GIT_URL="${K8S_GIT_URL:-https://github.com/pingidentity/ping-cloud-base}"
export K8S_GIT_BRANCH="${K8S_GIT_BRANCH:-master}"

export REGISTRY_NAME="${REGISTRY_NAME:-docker.io}"

# Print out the values being used for each variable.
echo "Using SIZE: ${SIZE}"
echo "Using TENANT_NAME: ${TENANT_NAME}"
echo "Using TENANT_DOMAIN: ${TENANT_DOMAIN}"
echo "Using REGION: ${REGION}"

echo "Using CLUSTER_STATE_REPO_URL: ${CLUSTER_STATE_REPO_URL}"
echo "Using CLUSTER_STATE_REPO_HOST: ${CLUSTER_STATE_REPO_HOST}"

echo "Using CONFIG_REPO_URL: ${CONFIG_REPO_URL}"
echo "Using CONFIG_REPO_BRANCH: ${CONFIG_REPO_BRANCH}"

echo "Using ARTIFACT_REPO_URL: ${ARTIFACT_REPO_URL}"
echo "Using LOG_ARCHIVE_URL: ${LOG_ARCHIVE_URL}"

echo "Using K8S_GIT_URL: ${K8S_GIT_URL}"
echo "Using K8S_GIT_BRANCH: ${K8S_GIT_BRANCH}"

echo "Using REGISTRY_NAME: ${REGISTRY_NAME}"
echo ---

export PING_IDENTITY_DEVOPS_USER_BASE64=$(echo -n "${PING_IDENTITY_DEVOPS_USER}" | base64)
export PING_IDENTITY_DEVOPS_KEY_BASE64=$(echo -n "${PING_IDENTITY_DEVOPS_KEY}" | base64)

SCRIPT_HOME=$(cd $(dirname ${0}); pwd)
TEMPLATES_HOME="${SCRIPT_HOME}/templates"

# Generate an SSH key pair for flux CD.
if test -z ${IDENTITY_PUB} && test -z ${IDENTITY_KEY}; then
  generate_ssh_key_pair
elif test -z ${IDENTITY_PUB} || test -z ${IDENTITY_KEY}; then
  echo 'Provide fluxcd key-pair via IDENTITY_PUB/IDENTITY_KEY environment variables, or omit both for key-pair to be generated'
  exit 1
fi

# Generate a self-signed cert for the tenant domain.
generate_tls_cert "${TENANT_DOMAIN}"

# Delete existing sandbox and re-create it
SANDBOX_DIR=/tmp/sandbox
rm -rf "${SANDBOX_DIR}"
mkdir -p "${SANDBOX_DIR}"

# Next build up the directory structure of the cluster-state repo
FLUXCD_DIR="${SANDBOX_DIR}/fluxcd"
mkdir -p "${FLUXCD_DIR}"

K8S_CONFIGS_DIR="${SANDBOX_DIR}/k8s-configs"
PING_CLOUD_DIR="${K8S_CONFIGS_DIR}/ping-cloud"
mkdir -p "${PING_CLOUD_DIR}"

# Now generate the yaml files for each environment
ENVIRONMENTS='dev test staging prod'

for ENV in ${ENVIRONMENTS}; do
  ENV_DIR="${PING_CLOUD_DIR}/${ENV}"

  # Export all the environment variables required for envsubst
  export ENVIRONMENT_GIT_PATH=${ENV}

  # The base URL for kustomization files, the cluster name and environment will be different for each CDE.
  # The cluster name will be PingPoc for prod, PingPoc-dev, PingPoc-test, PingPoc-staging for the different CDEs
  case "${ENV}" in
    prod)
      export KUSTOMIZE_BASE="prod/${SIZE}"
      export CLUSTER_NAME=${TENANT_NAME}
      export ENVIRONMENT=''
      ;;
    staging)
      export KUSTOMIZE_BASE='prod/small'
      export CLUSTER_NAME=${TENANT_NAME}-${ENV}
      export ENVIRONMENT="-${ENV}"
      ;;
    dev | test)
      export KUSTOMIZE_BASE='test'
      # FIXME: change to CLUSTER_NAME=${TENANT_NAME}-${ENV} when cluster setup is fixed
      export CLUSTER_NAME=${TENANT_NAME}
      export ENVIRONMENT="-${ENV}"
      ;;
  esac

  # Copy the shared cluster tools and Ping yaml templates into their target directories
  cp -r "${TEMPLATES_HOME}"/cluster-tools "${PING_CLOUD_DIR}"
  cp -r "${TEMPLATES_HOME}"/ping-cloud/cde "${ENV_DIR}"

  # Substitute variables in the environment directory
  substitute_vars "${PING_CLOUD_DIR}"

  # Generate the ping-cloud yaml file and move it into the environment directory
  ENV_YAML=$(mktemp)
  kustomize build "${ENV_DIR}" > "${ENV_YAML}"
  rm -rf "${ENV_DIR}"/*
  mv "${ENV_YAML}" "${ENV_DIR}"/ping.yaml

  # Generate the tools yaml file and move it into the environment directory
  TOOLS_YAML=$(mktemp)
  kustomize build "${PING_CLOUD_DIR}"/cluster-tools > "${TOOLS_YAML}"
  rm -rf "${PING_CLOUD_DIR}"/cluster-tools
  mv "${TOOLS_YAML}" "${ENV_DIR}"/tools.yaml

  # Copy the common files into the environment directory
  cp -r "${TEMPLATES_HOME}"/ping-cloud/common/* "${ENV_DIR}"
  substitute_vars "${ENV_DIR}"

  # Copy the flux yaml into the environment directory
  cp -r "${TEMPLATES_HOME}"/.flux.yaml "${ENV_DIR}"

  # Next, build the flux.yaml file for each environment
  ENV_FLUX_DIR="${FLUXCD_DIR}/${ENV}"
  mkdir -p "${ENV_FLUX_DIR}"

  cp "${TEMPLATES_HOME}"/fluxcd/* "${ENV_FLUX_DIR}"
  substitute_vars "${ENV_FLUX_DIR}"

  FLUX_YAML=$(mktemp)
  kustomize build "${ENV_FLUX_DIR}" > "${FLUX_YAML}"
  rm -rf "${ENV_FLUX_DIR}"/*
  mv "${FLUX_YAML}" "${ENV_FLUX_DIR}"/flux.yaml
done

echo "Push the directories under ${SANDBOX_DIR} into the tenant cluster-state repo onto the master branch"
echo "Add the following identity as a deploy key on the tenant cluster-state repo:"
echo "${IDENTITY_PUB}"