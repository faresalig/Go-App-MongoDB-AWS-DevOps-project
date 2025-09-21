################################################################
# EKS - corrected order + IRSA role for EBS CSI (no circular)
################################################################

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

locals {
  cluster_name = "${var.name_prefix}-${var.environment}"

  autoscaler_service_account_namespace = "kube-system"
  autoscaler_service_account_name      = "cluster-autoscaler-aws"

  admin_user_map_users = [
    for admin_user in var.admin_users : {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${admin_user}"
      username = admin_user
      groups   = ["system:masters"]
    }
  ]

  developer_user_map_users = [
    for developer_user in var.developer_users : {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${developer_user}"
      username = developer_user
      groups   = ["${var.name_prefix}-developers"]
    }
  ]
}

# Elastic IP for NAT GW
resource "aws_eip" "nat_gw_elastic_ip" {
  domain = "vpc"

  tags = {
    Name        = "${local.cluster_name}-nat-eip"
    Terraform   = "true"
    Environment = var.environment
  }
}

# 1) Create the EKS cluster first (without embedding the EBS CSI service_account_role_arn)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                    = local.cluster_name
  cluster_version                 = "1.28"
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  # don't pass service_account_role_arn here to avoid circular dependency
  cluster_addons = {
    coredns = { resolve_conflicts = "OVERWRITE" }
    kube-proxy = {}
    vpc-cni = { resolve_conflicts = "OVERWRITE" }
    # aws-ebs-csi-driver will be added separately
  }

  create_cloudwatch_log_group = false

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_security_group_additional_rules = {
    ingress_nodes_8443_tcp = {
      description                = "Node groups to cluster API via port 8443"
      protocol                   = "tcp"
      from_port                  = 8443
      to_port                    = 8443
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {
    system = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = var.asg_sys_instance_types
      labels = {
        Environment = var.environment
      }
      tags = {
        Terraform   = "true"
        Environment = var.environment
      }
    }
  }

  tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

# Create IRSA role for EBS CSI driver
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${local.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

# Enable EBS CSI driver addon
resource "aws_eks_addon" "aws_ebs_csi_driver" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.24.0-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"
  service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn

  depends_on = [module.ebs_csi_irsa_role]
}

# IAM role for cluster-autoscaler
module "iam_assumable_role_admin" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> 5.0"
  create_role                   = true
  role_name                     = "${local.cluster_name}-cluster-autoscaler"
  provider_url                  = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns              = [aws_iam_policy.cluster_autoscaler.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.autoscaler_service_account_namespace}:${local.autoscaler_service_account_name}"]

  tags = {
    Owner           = split("/", data.aws_caller_identity.current.arn)[1]
    AutoTag_Creator = data.aws_caller_identity.current.arn
  }
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name_prefix = "${local.cluster_name}-cluster-autoscaler"
  description = "EKS cluster-autoscaler policy for cluster ${module.eks.cluster_name}"
  policy      = data.aws_iam_policy_document.cluster_autoscaler.json
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  statement {
    sid    = "clusterAutoscalerAll"
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeLaunchTemplateVersions",
    ]

    resources = ["*"]
  }

  statement {
    sid    = "clusterAutoscalerOwn"
    effect = "Allow"

    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"
      values   = ["true"]
    }
  }
}
