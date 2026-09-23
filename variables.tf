variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "instance_type" {
  type    = string
  default = "t2.micro" # Strictly optimized for 100% AWS Free Tier coverage
}

variable "github_owner" {
  type        = string
  description = "Your exact GitHub username or organization name"
}

variable "github_repo" {
  type        = string
  description = "Your exact GitHub repository name (e.g., aws-3tier-vpc-production-infrastructure)"
}

variable "github_runner_token" {
  type        = string
  sensitive   = true
  description = "The token generated from GitHub Repository Settings -> Actions -> Runners"
}
