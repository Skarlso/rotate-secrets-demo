#!/bin/bash

set -e

POLL_INTERVAL=0.5
VAULT_NAMESPACE="default"
ESO_NAMESPACE="external-secrets"
DB_NAMESPACE="default"
OUTPUT_FILE="k8s_state.svg"
DOT_FILE="k8s_state.dot"


for cmd in kubectl dot; do
    if ! command -v $cmd &> /dev/null; then
        echo "I regret to inform you, my lord, that the command '$cmd' appears to be absent from your system."
        echo "May I suggest installing it before proceeding further?"
        exit 1
    fi
done

vault_ready=false
database_ready=false
eso_ready=false  # external-secrets-operator
vault_configured=false
psql_generator_ready=false  # The psql-example Generator object
psql_externalsecret_ready=false  # The psql-example-es ExternalSecret object
psql_secret_ready=false  # The final psql-example-for-use Secret

# Function to generate the Graphviz representation
generate_graph() {
    # Start with a pristine template
    cat > "$DOT_FILE" <<EOF
digraph kubernetes_state {
    style=filled;
    rankdir=TB;
    node [shape=box, style="rounded,filled", fontname="Arial", fontsize=12];
    edge [fontname="Arial", fontsize=10];
    
    bgcolor="white";
    
    Kubernetes [label="Kubernetes Cluster", fillcolor="#E5F5F9", color="#2980B9"];
EOF

    # Add Vault node with appropriate styling
    if $vault_ready; then
        echo "    Vault [label=\"Vault\", fillcolor=\"#D5F5E3\", color=\"#27AE60\"];" >> "$DOT_FILE"
        echo "    Kubernetes -> Vault [label=\"hosts\"];" >> "$DOT_FILE"
    else
        echo "    Vault [label=\"Vault\", fillcolor=\"#FADBD8\", color=\"#E74C3C\"];" >> "$DOT_FILE"
        echo "    Kubernetes -> Vault [label=\"pending\", style=\"dashed\"];" >> "$DOT_FILE"
    fi
    
    # Add External Secrets Operator node
    if $eso_ready; then
        echo "    ESO [label=\"External Secrets Operator\", fillcolor=\"#D5F5E3\", color=\"#27AE60\"];" >> "$DOT_FILE"
        echo "    Kubernetes -> ESO [label=\"hosts\"];" >> "$DOT_FILE"
    else
        echo "    ESO [label=\"External Secrets Operator\", fillcolor=\"#FADBD8\", color=\"#E74C3C\"];" >> "$DOT_FILE"
        echo "    Kubernetes -> ESO [label=\"pending\", style=\"dashed\"];" >> "$DOT_FILE"
    fi
    
    # Add Database node
    if $database_ready; then
        echo "    Postgres [label=\"Postgres\", fillcolor=\"#D5F5E3\", color=\"#27AE60\"];" >> "$DOT_FILE"
        echo "    Kubernetes -> Postgres [label=\"hosts\"];" >> "$DOT_FILE"
    else
        echo "    Postgres [label=\"Postgres\", fillcolor=\"#FADBD8\", color=\"#E74C3C\"];" >> "$DOT_FILE"
        echo "    Kubernetes -> Postgres [label=\"pending\", style=\"dashed\"];" >> "$DOT_FILE"
    fi
    
    # Add relationships for configured components
    if $vault_configured; then
        echo "    Vault -> Postgres [label=\"SQL Configuration\", color=\"#3498DB\", penwidth=2];" >> "$DOT_FILE"
    fi

    if $psql_generator_ready; then
        echo "    Generator [label=\"Generator: psql-example\", fillcolor=\"#E8DAEF\", color=\"#8E44AD\"];" >> "$DOT_FILE"
        echo "    ESO -> Generator [label=\"Manages\", color=\"#9B59B6\", penwidth=2];" >> "$DOT_FILE"
    fi

    if $psql_externalsecret_ready; then
        echo "    ExternalSecret [label=\"ExternalSecret: psql-example-es\", fillcolor=\"#FCF3CF\", color=\"#F1C40F\"];" >> "$DOT_FILE"
        echo "    ESO -> ExternalSecret [label=\"Manages\", color=\"#9B59B6\", penwidth=2];" >> "$DOT_FILE"
        echo "    ExternalSecret -> Generator [label=\"References\", color=\"#8E44AD\", penwidth=2];" >> "$DOT_FILE"
    fi
    
    if $psql_secret_ready; then
        echo "    Generator -> Vault [label=\"Fetches creds from\", color=\"#8E44AD\", penwidth=2];" >> "$DOT_FILE"
        echo "    Secret [label=\"Secret: psql-example-for-use\", fillcolor=\"#FDEDEC\", color=\"#E74C3C\"];" >> "$DOT_FILE"
        echo "    ExternalSecret -> Secret [label=\"Created\", color=\"#F1C40F\", penwidth=2];" >> "$DOT_FILE"
    fi
    
    # Close the graph definition with the required formality
    echo "}" >> "$DOT_FILE"
    
    # Generate the SVG with dot, as is proper
    dot -Tsvg "$DOT_FILE" -o "$OUTPUT_FILE"
    
    echo "I have updated the visualization. The current state is now rendered in $OUTPUT_FILE"
}

# Function to check Vault status
check_vault_status() {
    if kubectl get pod vault-0 -n "$VAULT_NAMESPACE" &>/dev/null; then
        VAULT_STATUS=$(kubectl get pod vault-0 -n "$VAULT_NAMESPACE" -o jsonpath='{.status.phase}')
        
        if [ "$VAULT_STATUS" = "Running" ]; then
            if ! $vault_ready; then
                echo "The Vault pod 'vault-0' has arrived and is operational."
                vault_ready=true
            fi
        else
            vault_ready=false
        fi
    else
        vault_ready=false
    fi
}

# Function to check External Secrets Operator status
check_eso_status() {
    if kubectl get deployment external-secrets -n "$ESO_NAMESPACE" &>/dev/null; then
        if kubectl get deployment external-secrets -n "$ESO_NAMESPACE" | grep -q "1/1"; then
            if ! $eso_ready; then
                echo "The External Secrets Operator has graced us with its presence."
                eso_ready=true
            fi        
        fi
    else
        eso_ready=false
    fi
}

# Function to check Database status
check_database_status() {
    # We shall check for a database deployment or statefulset
    if kubectl get deployment -n "$DB_NAMESPACE" postgres; then
        if ! $database_ready; then
            echo "Your database has arrived."
            database_ready=true
        fi
    else
        database_ready=false
    fi
}

# Function to check if Vault has been configured with SQL
check_vault_configuration() {
    if $vault_ready && $database_ready && ! $vault_configured; then
        if kubectl get service postgres; then
            echo "Postgres service is there, display the connection now."
            vault_configured=true
        fi
    fi
}

# Function to check for the psql Generator object
check_psql_generator() {
    if $vault_configured && $eso_ready && ! $psql_generator_ready; then
        if kubectl get VaultDynamicSecret -A 2>/dev/null | grep -q "psql-example"; then
            echo "The psql-example Generator has arrived."
            psql_generator_ready=true
        fi
    fi
}

# Function to check for the psql ExternalSecret object
check_psql_externalsecret() {
    if $psql_generator_ready && ! $psql_externalsecret_ready; then
        # Check for the specific ExternalSecret object
        if kubectl get externalsecret -A 2>/dev/null | grep -q "psql-example-es"; then
            echo "The psql-example-es ExternalSecret has been established."
            psql_externalsecret_ready=true
        fi
    fi
}

# Function to check for the final Secret
check_psql_secret() {
    if $psql_externalsecret_ready && ! $psql_secret_ready; then
        # Check for the final Secret object
        if kubectl get secret psql-example-for-use 2>/dev/null; then
            echo "The psql-example-for-use Secret has been successfully created."
            psql_secret_ready=true
        fi
    fi
}

# The main monitoring loop, executed with the utmost diligence
echo "Beginning the continuous monitoring."
echo "Updating vizuals in $POLL_INTERVAL seconds."
echo "To terminate this service, you may press Ctrl+C at your leisure."

while true; do
    check_vault_status
    check_eso_status
    check_database_status
    check_vault_configuration
    check_psql_generator
    check_psql_externalsecret
    check_psql_secret
    
    generate_graph
    
    sleep "$POLL_INTERVAL"
done