#!/bin/bash
set -e

setup_kubernetes() {
    payload=$1
    mkdir -p /root/.kube
    kubeconfig=$(jq -r '.source.kubeconfig // ""' < $payload)
        
    if [ -n "$kubeconfig" ]; then
        echo "$kubeconfig" > /root/.kube/config
    else
        echo "Must specify \"kubeconfig\" for authenticating to Kubernetes."
        exit 1
    fi
    
    kubectl version
}

setup_helm() {
    namespace=$(jq -r '.source.namespace // "default"' < $1)
    helm_request_base="helm -n $namespace"
    
    ca_cert=$(jq -r '.source.ca_cert // ""' < $1)
    client_cert=$(jq -r '.source.client_cert // ""' < $1)
    client_key=$(jq -r '.source.client_key // ""' < $1)
    
    if [ -n "$ca_cert" ]; then
        if [ -z "$client_cert" ]; then
            echo "Must specify \"client_cert\"!"
            exit 1
        fi
        
        if [ -z "$client_key" ]; then
            echo "Must specify \"client_key\"!"
            exit 1
        fi
        
        echo "$ca_cert" > $(helm home)/ca.pem
        echo "$client_cert" > $(helm home)/cert.pem
        echo "$client_key" > $(helm home)/key.pem
        
        helm_request_base="helm -n $namespace \
        --ca-file $(helm home)/ca.pem \
        --cert-file $(helm home)/cert.pem \
        --key-file $(helm home)/key.pem"
    fi
}

wait_for_service_up() {
    SERVICE=$1
    TIMEOUT=$2
    if [ "$TIMEOUT" -le "0" ]; then
        echo "Service $SERVICE was not ready in time"
        exit 1
    fi
    RESULT=`kubectl get endpoints --namespace=$tiller_namespace $SERVICE -o jsonpath={.subsets[].addresses[].targetRef.name} 2> /dev/null || true`
    if [ -z "$RESULT" ]; then
        sleep 1
        wait_for_service_up $SERVICE $((--TIMEOUT))
    fi
}

setup_resource() {
    echo "Initializing kubectl..."
    setup_kubernetes $1
    echo "Initializing helm..."
    setup_helm $1
}
