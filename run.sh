#!/bin/bash

set -e

BIN="bin"
mkdir -p "${BIN}"
kind="${BIN}/kind"
cluster_name=rotate-cluster

OS=$(uname | tr '[:upper:]' '[:lower:]')

download-kind() {
    if [[ -f "${BIN}/kind" ]]; then
        echo "kind exists"
        return
    fi

    echo "fetching kind"
    curl -Lo "${BIN}/kind" https://kind.sigs.k8s.io/dl/v0.27.0/kind-"${OS}"-amd64
    chmod +x "${BIN}/kind"
}

download-vault() {
    if [[ -f "${BIN}/vault" ]]; then
        echo "vault exists"
        return
    fi

    echo "fetching vault"
    curl -L https://releases.hashicorp.com/vault/1.19.1/vault_1.19.1_"${OS}"_amd64.zip -o vault.zip && unzip vault.zip -d "${BIN}" && rm vault.zip
    chmod +x "${BIN}/vault"
}

setup-vault() {
    kubectl apply -f vault-role.yaml
    kubectl apply -f vault-role-binding.yaml
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm repo update
    helm install vault hashicorp/vault --values helm-vault-raft-values.yaml

    echo "Waiting for pods with label 'app.kubernetes.io/name: vault' to exist..."
    until kubectl get pods -l "app.kubernetes.io/name=vault" --no-headers | grep -q .; do
        sleep 2
    done

    kubectl wait --for=jsonpath='{.status.phase}'=Running pod/vault-0

    kubectl exec vault-0 -- vault operator init \
        -key-shares=1 \
        -key-threshold=1 \
        -format=json >cluster-keys.json

    vault_token=$(jq -r ".unseal_keys_b64[]" cluster-keys.json)
    kubectl exec vault-0 -- vault operator unseal "${vault_token}"

    echo "waiting for vault to become ready after unsealing"
    kubectl wait --for=condition=Ready=true Pod/vault-0 --timeout=300s
}

apply-postgres-manifests() {
    kubectl apply -f manifests/postgres-config.yaml
    kubectl apply -f manifests/postgres-service.yaml
    kubectl apply -f manifests/postgres-deployment.yaml
    kubectl wait --for=condition=Available=true Deployment/postgres --timeout=300s
}

configure-postgres() {
    sleep 5
    kubectl exec "$(kubectl get pods -l app=postgres -o name)" -- sh -c "su postgres -c 'psql -c \"CREATE ROLE \\\"ro\\\" NOINHERIT;\" && psql -c \"GRANT SELECT ON ALL TABLES IN SCHEMA public TO \\\"ro\\\";\"'"

    vault_token=$(jq -r ".root_token" cluster-keys.json)
    kubectl exec vault-0 -- sh -c "echo \"${vault_token}\" | vault login -"
    kubectl exec vault-0 -- vault secrets enable database

    POSTGRES_URL=postgres.default.svc.cluster.local:5432
    kubectl exec vault-0 -- vault write database/config/postgresql \
        plugin_name=postgresql-database-plugin \
        connection_url="postgresql://admin:psltest@$POSTGRES_URL/postgres?sslmode=disable" \
        allowed_roles=readonly \
        username="root" \
        password="rootpassword"

    kubectl exec vault-0 -- sh -c "tee /tmp/readonly.sql <<EOF
CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' INHERIT;
GRANT ro TO \"{{name}}\";
EOF"

    kubectl exec vault-0 -- vault write database/roles/readonly \
      db_name=postgresql \
      creation_statements=@/tmp/readonly.sql \
      default_ttl=1h \
      max_ttl=24h

    # sleep 1

    kubectl exec vault-0 -- vault read database/creds/readonly
}

configure-external-secrets() {
    vault_token=$(jq -r ".root_token" cluster-keys.json)
    vault_token_encoded=$(echo -n "${vault_token}" | base64)

    echo "---
apiVersion: v1
kind: Secret
metadata:
  name: vault-token
data:
  token: ${vault_token_encoded}" | kubectl apply -f -

    kubectl apply -f manifests/generator.yaml
    kubectl apply -f manifests/external-secret.yaml
}

kind-create-test-cluster() {
    existing_clusters=$(kind get clusters)

    # Check if the cluster exists
    if echo "$existing_clusters" | grep -q "$cluster_name"; then
        echo "Cluster '$cluster_name' exists."
    else
        ${kind} create cluster --name "${cluster_name}" || true
    fi
}

deploy-external-secrets-operator() {
    helm repo add external-secrets https://charts.external-secrets.io
    helm repo update
    helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace || true
}

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

check-external-secrets-operator-deployment() {
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

echo "Setting up vault."

setup-vault

echo "Done setting up vault."

echo "Setting up Postgres deployment."

apply-postgres-manifests

echo "Configuring postgres."

configure-postgres

echo "Postgres configured."

echo "Creating external secrets manifests"

configure-external-secrets
