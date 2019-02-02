FROM alpine:3.7

ENV CLOUD_SDK_VERSION 201.0.0
ENV KUBECTL_VERSION 1.9.6
ENV HELM_VERSION 2.12.3

ENV PATH /google-cloud-sdk/bin:$PATH

ADD assets /opt/resource
RUN chmod +x /opt/resource/*

RUN apk --no-cache add \
        curl \
        python \
        py-crcmod \
        bash \
        libc6-compat \
        openssh-client \
        git \
        openssl \
        tar \
        jq \
        ca-certificates

RUN curl -L -o kubectl \
        https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
        && chmod 0700 kubectl \
        && mv kubectl /usr/bin

RUN curl -L -o helm.tar.gz \
        https://kubernetes-helm.storage.googleapis.com/helm-v${HELM_VERSION}-linux-amd64.tar.gz \
        && tar -xvzf helm.tar.gz \
        && rm -rf helm.tar.gz \
        && chmod 0700 linux-amd64/helm \
        && mv linux-amd64/helm /usr/bin \
        && rm -rf linux-amd64 \
        && helm init --client-only \
        && helm plugin install https://github.com/viglesiasce/helm-gcs.git

ENTRYPOINT [ "/bin/bash" ]
