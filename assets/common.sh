#!/bin/bash
set -e

setup_kubernetes() {
    payload=$1
    source=$2
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
    init_server=$(jq -r '.source.helm_init_server // "false"' < $1)
    namespace=$(jq -r '.source.namespace // "default"' < $1)
    tiller_namespace=$(jq -r '.source.tiller_namespace // "kube-system"' < $1)
    helm_request_base="helm --tiller-namespace $tiller_namespace"
    
    if [ "$init_server" = true ]; then
        tiller_service_account=$(jq -r '.source.tiller_service_account // "default"' < $1)

        sed -i -e 's/((tiller-namespace))/'$tiller_namespace'/g' /opt/resource/role-tiller.yml
        sed -i -e 's/((tiller-namespace))/'$tiller_namespace'/g' /opt/resource/rolebinding-tiller.yml
        kubectl apply -f /opt/resource/role-tiller.yml --namespace $namespace
        kubectl apply -f /opt/resource/rolebinding-tiller.yml --namespace $namespace

        helm init --tiller-namespace=$tiller_namespace --service-account=$tiller_service_account --upgrade
        wait_for_service_up tiller-deploy 10
    else
        helm init -c --tiller-namespace $tiller_namespace > /dev/null
    fi
    
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
        
        helm_request_base="helm --tiller-namespace $tiller_namespace \
        --tls --tls-verify \
        --tls-ca-cert $(helm home)/ca.pem \
        --tls-cert $(helm home)/cert.pem \
        --tls-key $(helm home)/key.pem"
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

setup_repos() {
    repos=$(jq -r '(try .source.repos[] catch [][]) | (.name+" "+.url)' < $1)
    tiller_namespace=$(jq -r '.source.tiller_namespace // "kube-system"' < $1)
    
    IFS=$'\n'
    for r in $repos; do
        name=$(echo $r | cut -f1 -d' ')
        url=$(echo $r | cut -f2 -d' ')
        echo Installing helm repository $name $url
        helm repo add --tiller-namespace $tiller_namespace $name $url
    done
}

setup_resource() {
    echo "Initializing kubectl..."
    setup_kubernetes $1 $2
    echo "Initializing helm..."
    setup_helm $1
    setup_repos $1
}
