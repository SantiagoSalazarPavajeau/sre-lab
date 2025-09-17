variable "aws_region" {
  description = "AWS region for LocalStack emulation"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key" {
  description = "Mock AWS access key"
  type        = string
  default     = "test"
}

variable "aws_secret_key" {
  description = "Mock AWS secret key"
  type        = string
  default     = "test"
}

variable "localstack_endpoint" {
  description = "LocalStack endpoint URL"
  type        = string
  default     = "http://localhost:4566"
}

variable "cluster_name" {
  description = "Logical name of the Kubernetes control plane that will run inside this VPC"
  type        = string
  default     = "sre-lab"
}

variable "vpc_cidr" {
  description = "CIDR block for the mock VPC"
  type        = string
  default     = "10.42.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets used by Kubernetes workers"
  type        = list(string)
  default     = [
    "10.42.1.0/24",
    "10.42.2.0/24"
  ]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets where services or data planes could live"
  type        = list(string)
  default     = [
    "10.42.11.0/24",
    "10.42.12.0/24"
  ]
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    project = "sre-lab"
  }
}
