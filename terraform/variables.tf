variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Short project identifier used in resource names"
  type        = string
  default     = "threetier"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
  default     = "dev"
}

# ---------- Networking ----------
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH into EC2. SET THIS TO YOUR PUBLIC IP/32 — never 0.0.0.0/0."
  type        = string
  default     = "0.0.0.0/0"
}

# ---------- Compute ----------
variable "ec2_instance_type" {
  description = "EC2 instance type (t2.micro / t3.micro are Free Tier eligible)"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 Key Pair in this region (create one in AWS Console first)"
  type        = string
}

# ---------- Database ----------
variable "db_instance_class" {
  description = "RDS instance class (db.t3.micro and db.t4g.micro are Free Tier eligible)"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB (Free Tier: up to 20 GB)"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for RDS (min 8 chars)"
  type        = string
  sensitive   = true
}

# ---------- Application ----------
variable "enable_nat_gateway" {
  description = "If true, creates a NAT Gateway so private-subnet EC2 can reach the internet. WARNING: NAT Gateway is NOT Free Tier and costs ~$0.045/hr. Leave false for pure Free Tier."
  type        = bool
  default     = false
}
