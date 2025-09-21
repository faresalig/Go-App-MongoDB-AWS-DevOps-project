variable "aws_access_key" {
  type        = string
  description = "AWS Access Key"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Key"
  sensitive   = true
}

variable "name_prefix" {
  type        = string
  default     = "cluster-1"
  description = "Prefix to be used on each infrastructure object Name created in AWS."
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region to deploy resources."

  validation {
    condition     = contains(["us-east-1", "us-west-2", "eu-west-1"], var.region)
    error_message = "Region must be one of: us-east-1, us-west-2, eu-west-1."
  }
}

variable "environment" {
  type        = string
  default     = "test"
  description = "Environment name (e.g., dev, test, prod)."
}

variable "admin_users" {
  type        = list(string)
  default     = ["Fares"]
  description = "List of Kubernetes admins."
}

variable "developer_users" {
  type        = list(string)
  default     = []
  description = "List of Kubernetes developers."
}

variable "main_network_block" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Base CIDR block to be used in our VPC."
}

variable "subnet_prefix_extension" {
  type        = number
  default     = 4
  description = "CIDR block bits extension to calculate CIDR blocks of each subnetwork."
}

variable "zone_offset" {
  type        = number
  default     = 8
  description = "CIDR block bits extension offset to calculate Public subnets, avoiding collisions with Private subnets."
}

variable "asg_sys_instance_types" {
  type        = list(string)
  default     = ["t3a.medium"]
  description = "List of EC2 instance types for system workloads in EKS."
}

variable "asg_dev_instance_types" {
  type        = list(string)
  default     = ["t3a.medium"]
  description = "List of EC2 instance types for development workloads in EKS."
}

variable "autoscaling_minimum_size_by_az" {
  type        = number
  default     = 1
  description = "Minimum number of EC2 instances to auto-scale our EKS cluster per AZ."
}

variable "autoscaling_maximum_size_by_az" {
  type        = number
  default     = 2
  description = "Maximum number of EC2 instances to auto-scale our EKS cluster per AZ."
}

variable "autoscaling_average_cpu" {
  type        = number
  default     = 60
  description = "Average CPU threshold (percentage) to auto-scale EKS EC2 instances."
}
