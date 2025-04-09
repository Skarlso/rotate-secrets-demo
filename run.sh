#!/bin/bash

set -e

BIN="bin"
mkdir -p "${BIN}"

OS=$(uname)

download-kind() {
    if [[ -f "${BIN}/kind" ]]; then
        echo "kind exists"
        return
    fi

    echo "fetching kind"
    case "$OS" in
    "Linux")
        # Download the Linux binary (adjust URL to your needs)
        curl -Lo "${BIN}/kind" https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
        ;;
    "Darwin")
        # Download the macOS binary (adjust URL to your needs)
        curl -Lo "${BIN}/kind" https://kind.sigs.k8s.io/dl/v0.27.0/kind-darwin-amd64
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
    esac

    chmod +x "${BIN}/kind"
}

download-vault() {
    if [[ -f "${BIN}/vault" ]]; then
        echo "vault exists"
        return
    fi

    echo "fetching vault"
    case "$OS" in
    "Linux")
        # Download the Linux binary (adjust URL to your needs)
        curl -Lo "${BIN}/kind" https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
        ;;
    "Darwin")
        # Download the macOS binary (adjust URL to your needs)
        curl -Lo "${BIN}/kind" https://kind.sigs.k8s.io/dl/v0.27.0/kind-darwin-amd64
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
    esac

    chmod +x "${BIN}/vault"
}

kind-create-test-cluster() {
    kind create cluster --name rotate-cluster
}

deploy-external-secrets-operator() {
    helm repo add external-secrets https://charts.external-secrets.io
    helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
}

check-external-secrets-operator-deployment() {
    spinner() {
        local pid=$1
        local delay=0.2
        local spinstr='|/-\\'
        while kill -0 "$pid" 2>/dev/null; do
            local temp=${spinstr#?}
            printf " [%c]  \r" "$spinstr"
            spinstr=$temp${spinstr%"$temp"}
            sleep $delay
        done
        echo "    "
    }

    kubectl wait --for=condition=Available=true Deployment/external-secrets -n external-secrets --timeout=300s &
    spinner $!
    kubectl wait --for=condition=Available=true Deployment/external-secrets-cert-controller -n external-secrets --timeout=300s &
    spinner $!
    kubectl wait --for=condition=Available=true Deployment/external-secrets-webhook -n external-secrets --timeout=300s &
    spinner $!
}

apply-store-manifest() {
    echo "applying store manifest"
}

echo "Starting environment setup for external-secrets-operator secrets rotation demo..."

download-kind

download-vault

kind-create-test-cluster

echo "Test cluster started... installing external-secrets-operator"

deploy-external-secrets-operator

echo "Waiting for 5 minutes for external-secrets-operator to be Ready"

check-external-secrets-operator-deployment

echo "Operator deployed."

echo "Applying secrets and other manifests."
