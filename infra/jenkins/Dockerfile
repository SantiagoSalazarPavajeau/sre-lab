FROM jenkins/jenkins:lts-jdk17

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    lsb-release \
    python3 \
    python3-pip \
    unzip \
    apt-transport-https && \
    rm -rf /var/lib/apt/lists/*

ARG KUBECTL_VERSION=v1.29.2
ARG KIND_VERSION=v0.20.0
ARG TERRAFORM_VERSION=1.6.6
ARG YQ_VERSION=v4.43.1

RUN curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod +x /usr/local/bin/kubectl

RUN curl -fsSLo /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" && \
    chmod +x /usr/local/bin/kind

RUN curl -fsSLo /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" && \
    unzip /tmp/terraform.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/terraform && \
    rm /tmp/terraform.zip

RUN curl -fsSLo /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" && \
    chmod +x /usr/local/bin/yq

# Allow Jenkins to talk to the host Docker daemon
RUN groupadd -g 999 docker || true && usermod -aG docker jenkins

USER jenkins

ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"

