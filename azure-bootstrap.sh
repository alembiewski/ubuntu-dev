#!/bin/bash
set -euox pipefail


dkp create bootstrap --kubeconfig $HOME/.kube/config
kubectl create -f kostas-azure-example.yaml
dkp get kubeconfig -c kostas-azure-example5 > kostas-azure-example5.conf
dkp create capi-components  --kubeconfig kostas-azure-example5.conf
dkp --kubeconfig=kostas-azure-example5.conf install kommander --installer-config ${IR}/hack/create-environments/minimal-insights-kommander-installer-config.yaml
# dkp --kubeconfig=kostas-azure-example5.conf open dashboard
