module "infrastructure" {
  source              = "./modules/single_region_infra"
  vpc_cidr            = var.vpc_cidr
  instance_type       = var.instance_type
  github_owner        = var.github_owner
  github_repo         = var.github_repo
  github_runner_token = var.github_runner_token
}

output "public_alb_dns" {
  value       = module.infrastructure.public_alb_dns
  description = "Access your application using this URL link once the pipeline finishes deploying."
}

output "database_endpoint" {
  value       = module.infrastructure.database_endpoint
  description = "Add this value as your AWS_RDS_ENDPOINT secret inside your GitHub repository settings."
}
