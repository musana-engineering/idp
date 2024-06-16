# Use Alpine Linux as the base image
FROM alpine:latest

# Install necessary packages and dependencies
RUN apk update && apk add --no-cache \
    sudo \
    bash \
    wget \
    curl \
    git \
    ansible \
    python3 \
    py3-pip \
    gcc \
    python3-dev \
    musl-dev \
    linux-headers \
    shadow \
    && pip3 install --upgrade pip --break-system-packages \
    && pip3 install azure-cli --break-system-packages \
    && wget https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip \
    && unzip terraform_1.8.5_linux_amd64.zip -d /usr/local/bin/ \
    && rm terraform_1.8.5_linux_amd64.zip \
    && curl -LO https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl \
    && curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 \
    && chmod +x /usr/local/bin/argocd \
    && curl -sSL -o /usr/local/bin/kubelogin https://github.com/Azure/kubelogin/releases/latest/download/kubelogin-linux-amd64.zip \
    && unzip /usr/local/bin/kubelogin -d /usr/local/bin/ \
    && rm /usr/local/bin/kubelogin

# Create the devops user and set up sudo
RUN adduser -D -h /home/devops devops \
    && echo "devops ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set the working directory to the home directory of the devops user
WORKDIR /home/devops

# Change ownership of all files to the devops user
RUN chown -R devops:devops /home/devops

# Switch to the devops user
USER devops

# Set up environment variables for Azure CLI (optional)
ENV PATH="$PATH:/home/devops/.local/bin"

# Define the entrypoint
ENTRYPOINT ["/bin/bash"]
