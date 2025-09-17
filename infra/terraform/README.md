# Terraform Infrastructure (LocalStack)

This module provisions a mock AWS footprint that mirrors the networking and IAM boundaries an EKS cluster would normally depend on. The configuration is pinned to LocalStack so you can practice Terraform workflows without touching a real AWS account.

## Layout

- **VPC / Subnets** – public and private subnets tagged for Kubernetes load balancers.
- **Security Groups** – control plane and node groups with permissive sample rules.
- **IAM Roles** – placeholder roles Terraform can hand to EKS or other automation.
- **ECR & S3** – backing services for container artefacts and Terraform state.

## Usage

1. Launch LocalStack (see `infra/localstack/docker-compose.yml`).
2. Run Terraform inside this directory:

   ```bash
   terraform init
   terraform workspace select localstack || terraform workspace new localstack
   terraform plan -var-file="environments/localstack.tfvars"
   terraform apply -auto-approve -var-file="environments/localstack.tfvars"
   ```

3. Inspect outputs to feed into cluster/bootstrap scripts:

   ```bash
   terraform output
   ```

When you are finished experimenting, tear the stack down:

```bash
terraform destroy -auto-approve -var-file="environments/localstack.tfvars"
```

> **Tip:** To experiment with multiple environments, create additional `.tfvars` files under `environments/` and switch with `terraform workspace select`.
