#!/bin/sh
# This script executes the Kubernetes conformance tests in accordance with:
# https://github.com/cncf/k8s-conformance/blob/master/instructions.md
#
# Usage:
#   conformance_tests.sh <path to minikube> <flags>
#
# Example:
#   conformance_tests.sh ./out/minikube --vm-driver=hyperkit
set -ex -o pipefail

readonly PROFILE_NAME="k8sconformance"
readonly MINIKUBE=${1:-./out/minikube}
shift || true
readonly START_ARGS=$*

# Requires a fully running Kubernetes cluster.
"${MINIKUBE}" delete -p "${PROFILE_NAME}" || true
"${MINIKUBE}" start -p "${PROFILE_NAME}" $START_ARGS
"${MINIKUBE}" status -p "${PROFILE_NAME}"
kubectl get pods --all-namespaces

go get -u -v github.com/heptio/sonobuoy
sonobuoy run --wait
outdir="$(mktemp -d)"
sonobuoy retrieve "${outdir}"

cwd=$(pwd)

cd "${outdir}"
mkdir ./results; tar xzf *.tar.gz -C ./results

version=$(${MINIKUBE} version  | cut -d" " -f3)

mkdir minikube-${version}
cd minikube-${version}

cat <<EOF >PRODUCT.yaml
vendor: minikube
name: minikube
version: ${version}
website_url: https://github.com/kubernetes/minikube
repo_url: https://github.com/kubernetes/minikube
documentation_url: https://github.com/kubernetes/minikube/blob/master/docs/README.md
product_logo_url: https://raw.githubusercontent.com/kubernetes/minikube/master/images/logo/logo.svg
type: installer
description: minikube runs a local Kubernetes cluster on macOS, Linux, and Windows.
EOF

cat <<EOF >README.md
./hack/conformance_tests.sh $MINIKUBE $START_ARGS
EOF

cp ../results/plugins/e2e/results/* .
cd ..
cp -r minikube-${version} ${cwd}
