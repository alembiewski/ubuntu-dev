#!/bin/bash
set -euox pipefail

export BACKEND_KUBECONFIG=${IR}/artifacts/backend.kubeconfig
export MANAGEMENT_KUBECONFIG=${IR}/artifacts/management.kubeconfig
export USE_KIND_CLUSTERS=true
export INSIGHTS_NAMESPACE=kommander
export SKIP_AWS_CREDENTIALS=true

cd "${IR}"
# Create Kind cluster
./hack/create-environments/create-environments.sh create-management-cluster

# Create a symlink for the backend cluster config to point to the management cluster
./hack/create-environments/create-environments.sh create-backend-cluster

# Install Kommander
./hack/create-environments/create-environments.sh install-kommander
# Enable Entrprise
./hack/create-environments/create-environments.sh enable-enterprise-license

# Install Insights Snapshot
make kind-install-helm-management-snapshot
# make kind-install-helm-backend-snapshot
