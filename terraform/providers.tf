# Get EKS cluster info
data "aws_eks_cluster" "this" {
  name = "${var.name_prefix}-${var.environment}"
}

# Get authentication token for EKS cluster
data "aws_eks_cluster_auth" "this" {
  name = "${var.name_prefix}-${var.environment}"
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
