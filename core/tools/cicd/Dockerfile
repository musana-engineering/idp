# Use the latest Alpine image
FROM alpine:latest

# Set environment variables for Terraform and provider versions
ENV TERRAFORM_VERSION=1.4.6
ENV TERRAFORM_PROVIDER_AZURERM=3.64.0
ENV TERRAFORM_PROVIDER_K8S=1.0.0
ENV TERRAFORM_PROVIDER_VAULT=3.13.0

# Install necessary packages
RUN apk add --no-cache bash curl openssl unzip

# Download and install Terraform
ADD https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip ./
RUN unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin && \
    rm -f terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Create a non-root user and directories
RUN addgroup -S devopsadmin && \
    adduser -S -D -h /home/devopsadmin -G devopsadmin devopsadmin && \
    mkdir -p /home/devopsadmin/terraform.d/plugins/linux_amd64/

# Download and install Terraform providers
ADD https://releases.hashicorp.com/terraform-provider-azurerm/${TERRAFORM_PROVIDER_AZURERM}/terraform-provider-azurerm_${TERRAFORM_PROVIDER_AZURERM}_linux_amd64.zip ./
RUN unzip terraform-provider-azurerm_${TERRAFORM_PROVIDER_AZURERM}_linux_amd64.zip -d /home/devopsadmin/terraform.d/plugins/linux_amd64/ && \
    rm -f terraform-provider-azurerm_${TERRAFORM_PROVIDER_AZURERM}_linux_amd64.zip

ADD https://releases.hashicorp.com/terraform-provider-vault/${TERRAFORM_PROVIDER_VAULT}/terraform-provider-vault_${TERRAFORM_PROVIDER_VAULT}_linux_amd64.zip ./
RUN unzip terraform-provider-vault_${TERRAFORM_PROVIDER_VAULT}_linux_amd64.zip -d /home/devopsadmin/terraform.d/plugins/linux_amd64/ && \
    rm -f terraform-provider-vault_${TERRAFORM_PROVIDER_VAULT}_linux_amd64.zip

ADD https://github.com/banzaicloud/terraform-provider-k8s/releases/download/v${TERRAFORM_PROVIDER_K8S}/terraform-provider-k8s_${TERRAFORM_PROVIDER_K8S}_linux_amd64.tar.gz ./
RUN tar -xzf terraform-provider-k8s_${TERRAFORM_PROVIDER_K8S}_linux_amd64.tar.gz -C /home/devopsadmin/terraform.d/plugins/linux_amd64/ && \
    mv /home/devopsadmin/terraform.d/plugins/linux_amd64/terraform-provider-k8s_${TERRAFORM_PROVIDER_K8S}_linux_amd64 /home/devopsadmin/terraform.d/plugins/linux_amd64/terraform-provider-k8s_v${TERRAFORM_PROVIDER_K8S} && \
    rm -f terraform-provider-k8s_${TERRAFORM_PROVIDER_K8S}_linux_amd64.tar.gz && \
    chmod +x /home/devopsadmin/terraform.d/plugins/linux_amd64/terraform-provider-k8s_v${TERRAFORM_PROVIDER_K8S}

# Set ownership and permissions
RUN chown -R devopsadmin:devopsadmin /home/devopsadmin && \
    chmod -R +x /home/devopsadmin/terraform.d/plugins/linux_amd64/

# Switch to the non-root user
USER devopsadmin

# Set the working directory
WORKDIR /home/devopsadmin/
