variable "aws_region" {
  description = "AWS region where the resources will be deployed."
  type        = string
  default     = "eu-north-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet where the bastion host resides."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_master_cidr" {
  description = "CIDR block for the private subnet where the K3s master node resides."
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_worker_cidr" {
  description = "CIDR block for the private subnet where the K3s worker node resides."
  type        = string
  default     = "10.0.3.0/24"
}

variable "availability_zone_1" {
  description = "Availability Zone for the public subnet and K3s master subnet."
  type        = string
  default     = "eu-north-1a"
}

variable "availability_zone_2" {
  description = "Availability Zone for the K3s worker subnet."
  type        = string
  default     = "eu-north-1b"
}

variable "instance_type" {
  description = "EC2 instance type for all nodes (bastion, master, worker). Using t3.micro for Free Tier compliance."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of the SSH key pair to be created in AWS."
  type        = string
  default     = "k3s-cluster-key"
}

variable "private_key_path" {
  description = "Local path where the generated SSH private key will be saved."
  type        = string
  default     = "k3s-cluster-key.pem"
}