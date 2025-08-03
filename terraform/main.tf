# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Data source to get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# --- VPC and Networking ---

resource "aws_vpc" "k3s_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "k3s-cluster-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.k3s_vpc.id

  tags = {
    Name = "k3s-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.k3s_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone_1
  map_public_ip_on_launch = true # Instances in this subnet get a public IP

  tags = {
    Name = "k3s-public-subnet"
  }
}

resource "aws_subnet" "private_master" {
  vpc_id                  = aws_vpc.k3s_vpc.id
  cidr_block              = var.private_subnet_master_cidr
  availability_zone       = var.availability_zone_1
  map_public_ip_on_launch = false

  tags = {
    Name = "k3s-private-subnet-master"
  }
}

resource "aws_subnet" "private_worker" {
  vpc_id                  = aws_vpc.k3s_vpc.id
  cidr_block              = var.private_subnet_worker_cidr
  availability_zone       = var.availability_zone_2
  map_public_ip_on_launch = false

  tags = {
    Name = "k3s-private-subnet-worker"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.k3s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "k3s-public-rt"
  }
}

# No private route table with NAT Gateway needed if communication is only via bastion
# and no direct internet access is required from private subnets for K3s installation or updates.

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "private_master" {
  subnet_id      = aws_subnet.private_master.id
  route_table_id = aws_route_table.public_route_table.id # Associate private subnet with public RT
}

resource "aws_route_table_association" "private_worker" {
  subnet_id      = aws_subnet.private_worker.id
  route_table_id = aws_route_table.public_route_table.id # Associate private subnet with public RT
}

# --- Security Groups ---

# Security Group for Bastion Host
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH to bastion host"
  vpc_id      = aws_vpc.k3s_vpc.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # For local access; tighten in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }

  tags = {
    Name = "bastion-sg"
  }
}

# Security Group for K3s Master and Worker Nodes
resource "aws_security_group" "k3s_node_sg" {
  name        = "k3s-node-sg"
  description = "Allow SSH from bastion and K3s cluster traffic"
  vpc_id      = aws_vpc.k3s_vpc.id

  # Allow SSH from bastion host
  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Allow K3s server API and cluster communication
  ingress {
    description = "K3s API and inter-node communication"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr] # Allow from within VPC
  }

  # Allow all traffic within the security group for K3s nodes to communicate
  ingress {
    description     = "Allow all traffic within K3s nodes"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.k3s_node_sg.id]
  }

  # Allow outbound traffic to the internet ONLY via the bastion host's IP if strictly enforced
  # For the K3s installation itself, direct outbound to the internet might be needed
  # If you truly want ALL internet traffic via bastion, you'd need a proxy setup.
  # For simplicity, we'll keep egress open for now to allow K3s install.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic for K3s installation/updates
  }

  tags = {
    Name = "k3s-node-sg"
  }
}

# --- SSH Key Pair ---
# Generate a new TLS private key
resource "tls_private_key" "generated" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Save the private key to a local file
resource "local_file" "private_key_pem" {
  content         = tls_private_key.generated.private_key_pem
  filename        = var.private_key_path
  file_permission = "0600" # Important for SSH
}

# Upload the public key to AWS
resource "aws_key_pair" "k3s_key" {
  key_name   = var.key_name
  public_key = tls_private_key.generated.public_key_openssh

  lifecycle {
    ignore_changes = [key_name] # Prevent Terraform from deleting and recreating if key_name changes
  }
}

# --- EC2 Instances ---

# Bastion Host
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  key_name                    = aws_key_pair.k3s_key.key_name
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true # Bastion needs a public IP

  tags = {
    Name = "k3s-bastion"
  }
}

# K3s Master Node
resource "aws_instance" "k3s_master" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private_master.id
  key_name                    = aws_key_pair.k3s_key.key_name
  vpc_security_group_ids      = [aws_security_group.k3s_node_sg.id]
  associate_public_ip_address = false # Master is in private subnet

  user_data = <<-EOF
              #!/bin/bash
              # K3s installation might require direct internet access for `curl`
              # If strict proxying via bastion is needed, a proxy configuration
              # would be required here. For basic K3s install, direct access is assumed.
              curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644
              # Store the K3s token for worker nodes
              sudo cp /var/lib/rancher/k3s/server/node-token /tmp/k3s_node_token
              EOF

  tags = {
    Name = "k3s-master"
  }
}

# K3s Worker Node
resource "aws_instance" "k3s_worker" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private_worker.id
  key_name                    = aws_key_pair.k3s_key.key_name
  vpc_security_group_ids      = [aws_security_group.k3s_node_sg.id]
  associate_public_ip_address = false # Worker is in private subnet

  user_data = templatefile("${path.module}/join_worker.sh.tpl", {
    master_ip = aws_instance.k3s_master.private_ip
  })

  # The worker needs to wait for the master to be up and have its token
  depends_on = [aws_instance.k3s_master]

  tags = {
    Name = "k3s-worker"
  }
}

