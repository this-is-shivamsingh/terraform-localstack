# Configure the AWS provider for LocalStack
provider "aws" {
  region = "us-east-1"  # LocalStack supports this region by default

  # LocalStack specific configurations
  access_key = "test"    # Default LocalStack credentials
  secret_key = "test"    # Default LocalStack credentials
  
  # Override endpoints to point to LocalStack
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3 = "http://localhost:4566"  # Default LocalStack port
    eks = "http://localhost:4566"
    iam = "http://localhost:4566"
    ec2 = "http://localhost:4566"
    ecr = "http://localhost:4566"
  }
}

# Create the S3 bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-localstack-bucket"  # No global uniqueness required for LocalStack
}

# Upload a text file to the bucket
resource "aws_s3_object" "text_file" {
  bucket       = aws_s3_bucket.my_bucket.id
  key          = "example.txt"
  content      = "Hello, this is a sample text file in LocalStack!"
  content_type = "text/plain"
}


# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

# Attach the AmazonEKSClusterPolicy to the role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS Cluster
resource "aws_eks_cluster" "localstack_eks" {
  name     = "localstack-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = ["subnet-12345678"] # Placeholder subnet ID for LocalStack
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# Outputs
output "eks_cluster_endpoint" {
  value = aws_eks_cluster.localstack_eks.endpoint
}

output "eks_cluster_name" {
  value = aws_eks_cluster.localstack_eks.name
}

# ECR ( elastic container registry )
resource "aws_ecr_repository" "nginx_repo" {
  name = "nginx-repo"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.nginx_repo.repository_url
}


######## Creating worker nodes, on which pods will get deployed
######## Node group -> ecr repo/nginx-repo read access only

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Attach Policies to Node Role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}


# Custom IAM Policy for EKS CNI
resource "aws_iam_policy" "eks_cni_policy_custom" {
  name        = "eks-cni-policy-custom"
  description = "Custom policy for EKS CNI permissions in LocalStack"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AssignPrivateIpAddresses",
          "ec2:AttachNetworkInterface",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeInstanceTypes",
          "ec2:DetachNetworkInterface",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = "arn:aws:ec2:*:*:network-interface/*"
      }
    ]
  })
}

# Attach the Custom Policy to the Node Role
# As, AmazonEKSCNIPolicy policy was not working for localstack, so we create a custom
# CNI policy similar to AmazonEKSCNIPolicy, and used it
# CNI policy given EKS, control plan permission to manage cluster and nodes on your behalf
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = aws_iam_policy.eks_cni_policy_custom.arn # Use custom policy ARN
}

# resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
#   role       = aws_iam_role.eks_node_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKSCNIPolicy"
# }

# Custom IAM Policy for Specific ECR Repo Read Access
resource "aws_iam_policy" "ecr_nginx_repo_read" {
  name        = "ecr-nginx-repo-read-policy"
  description = "Read-only access to nginx-repo ECR repository"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = "arn:aws:ecr:us-east-1:000000000000:repository/nginx-repo"
      },
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      }
    ]
  })
}

# Attach the Custom Policy to the Node Role
resource "aws_iam_role_policy_attachment" "ecr_nginx_repo_read_attachment" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = aws_iam_policy.ecr_nginx_repo_read.arn
}

# EKS Node Group
resource "aws_eks_node_group" "localstack_node_group" {
  cluster_name    = aws_eks_cluster.localstack_eks.name
  node_group_name = "localstack-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = ["subnet-12345678"]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["t2.micro"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_nginx_repo_read_attachment,
  ]
}

# kubernetics deployment
provider "kubernetes" {
  config_path = "~/.kube/config" # Minikube’s kubeconfig
}
