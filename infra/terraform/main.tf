locals {
  az_suffixes = ["a", "b", "c"]

  public_subnet_map = {
    for idx, cidr in var.public_subnet_cidrs :
    idx => {
      cidr = cidr
      az   = "${var.aws_region}${local.az_suffixes[idx % length(local.az_suffixes)]}"
    }
  }

  private_subnet_map = {
    for idx, cidr in var.private_subnet_cidrs :
    idx => {
      cidr = cidr
      az   = "${var.aws_region}${local.az_suffixes[idx % length(local.az_suffixes)]}"
    }
  }

  cluster_tag = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = local.public_subnet_map

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(var.tags, local.cluster_tag, {
    Name                     = "${var.cluster_name}-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private" {
  for_each = local.private_subnet_map

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.tags, local.cluster_tag, {
    Name                          = "${var.cluster_name}-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Control plane access"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow API server"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow kubelet to API server"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, local.cluster_tag, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

resource "aws_security_group" "nodes" {
  name        = "${var.cluster_name}-nodes-sg"
  description = "Node group access"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow node-to-node traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "Allow control-plane-to-node traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, local.cluster_tag, {
    Name = "${var.cluster_name}-nodes-sg"
  })
}

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "cluster_policy" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
      "iam:List*",
      "iam:Get*",
      "iam:PassRole",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "cluster" {
  name   = "${var.cluster_name}-cluster-policy"
  role   = aws_iam_role.cluster.id
  policy = data.aws_iam_policy_document.cluster_policy.json
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nodes" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "node_policy" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:Describe*",
      "ec2:AttachVolume",
      "ec2:CreateSnapshot",
      "ec2:CreateVolume",
      "ec2:DeleteVolume",
      "ec2:DetachVolume",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:DescribeTargetGroups",
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "s3:ListBucket",
      "s3:GetObject"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "node" {
  name   = "${var.cluster_name}-node-policy"
  role   = aws_iam_role.nodes.id
  policy = data.aws_iam_policy_document.node_policy.json
}

resource "aws_ecr_repository" "apps" {
  name                 = "${var.cluster_name}/apps"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = var.tags
}

resource "aws_s3_bucket" "artefacts" {
  bucket = "${var.cluster_name}-artefacts"

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "artefacts" {
  bucket = aws_s3_bucket.artefacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

output "vpc_id" {
  description = "The VPC hosting the mock Kubernetes control plane"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet identifiers for load balancers"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "Private subnet identifiers for internal services"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "cluster_security_group_id" {
  description = "Security group assigned to the logical Kubernetes control plane"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group assigned to worker nodes"
  value       = aws_security_group.nodes.id
}

output "cluster_role_arn" {
  description = "IAM role for the EKS control plane"
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "IAM role for the node group"
  value       = aws_iam_role.nodes.arn
}

output "ecr_repository_url" {
  description = "ECR repository for lab container images"
  value       = aws_ecr_repository.apps.repository_url
}

output "artefact_bucket" {
  description = "S3 bucket for Terraform state or deployment artefacts"
  value       = aws_s3_bucket.artefacts.bucket
}
