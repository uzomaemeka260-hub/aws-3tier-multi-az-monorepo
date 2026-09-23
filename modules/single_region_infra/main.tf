variable "vpc_cidr"            { type = string }
variable "instance_type"       { type = string }
variable "github_owner"        { type = string }
variable "github_repo"         { type = string }
variable "github_runner_token" { type = string }

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-2023/x86_64/standard/latest"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "production-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main-igw" }
}

resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "public-sub-${count.index + 1}" }
}

resource "aws_subnet" "private_app_1" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 3)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { Name = "priv-nginx-sub-${count.index + 1}" }
}

resource "aws_subnet" "private_app_2" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 6)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { Name = "priv-backend-sub-${count.index + 1}" }
}

resource "aws_subnet" "database" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 9)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { Name = "database-sub-${count.index + 1}" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.igw]
  tags          = { Name = "shared-nat-gateway" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {
  count          = 3
  subnet_id      = aws_subnet.private_app_1[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  count          = 3
  subnet_id      = aws_subnet.private_app_2[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "public_alb" {
  name   = "public-alb-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "nginx_proxy" {
  name   = "nginx-proxy-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.public_alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "internal_alb" {
  name   = "internal-alb-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.nginx_proxy.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "backend_app" {
  name   = "backend-app-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "efs_nfs" {
  name   = "efs-shared-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_app.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "database" {
  name   = "database-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_app.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ssm_role" {
  name = "EC2-SSM-Execution-Role-VPC"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "EC2-SSM-Profile-VPC"
  role = aws_iam_role.ssm_role.name
}

resource "aws_efs_file_system" "nfs" {
  encrypted = true
}

resource "aws_efs_mount_target" "nfs" {
  count           = 3
  file_system_id  = aws_efs_file_system.nfs.id
  subnet_id       = aws_subnet.private_app_2[count.index].id
  security_groups = [aws_security_group.efs_nfs.id]
}

resource "aws_db_subnet_group" "db_group" {
  name       = "db-subnet-group-vpc"
  subnet_ids = aws_subnet.database[*].id
}

resource "aws_db_instance" "postgres" {
  identifier             = "production-db-vpc"
  allocated_storage      = 20
  max_allocated_storage  = 40
  engine                 = "postgres"
  engine_version         = "15.4"
  instance_class         = "db.t3.micro"
  db_name                = "app_production"
  username               = "dbadmin"
  password               = "SecurePostgresPass123!"
  db_subnet_group_name   = aws_db_subnet_group.db_group.name
  vpc_security_group_ids = [aws_security_group.database.id]
  multi_az               = true
  skip_final_snapshot    = true
  storage_encrypted      = true
}

resource "aws_lb" "public" {
  name               = "public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.public_alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "nginx" {
  name     = "tg-nginx"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "public" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx.arn
  }
}

resource "aws_lb" "internal" {
  name               = "alb-internal"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.internal_alb.id]
  subnets            = aws_subnet.private_app_1[*].id
}

resource "aws_lb_target_group" "backend" {
  name     = "tg-backend"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener" "internal" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

resource "aws_launch_template" "nginx" {
  name_prefix            = "lt-nginx-"
  image_id               = data.aws_ssm_parameter.ami.value
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.nginx_proxy.id]
  iam_instance_profile {
    arn = aws_iam_instance_profile.ssm_profile.arn
  }
  user_data = base64encode(<<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y nginx
    sudo systemctl enable nginx --now
    cat <<'NCONF' > /etc/nginx/conf.d/proxy.conf
    server {
      listen 80;
      location / { proxy_pass http://localhost:80; }
      location /api/ { proxy_pass http://${aws_lb.internal.dns_name}:80; }
    }
    NCONF
    sudo systemctl restart nginx
  EOF
  )
}

resource "aws_autoscaling_group" "nginx" {
  name                = "asg-nginx"
  vpc_zone_identifier = aws_subnet.private_app_1[*].id
  target_group_arns   = [aws_lb_target_group.nginx.arn]
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  launch_template {
    id      = aws_launch_template.nginx.id
    version = "$Latest"
  }
}

resource "aws_launch_template" "backend" {
  name_prefix            = "lt-backend-"
  image_id               = data.aws_ssm_parameter.ami.value
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.backend_app.id]
  iam_instance_profile {
    arn = aws_iam_instance_profile.ssm_profile.arn
  }
  user_data = base64encode(<<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker
    sudo systemctl enable docker --now
  EOF
  )
}

resource "aws_autoscaling_group" "backend" {
  name                = "asg-backend"
  vpc_zone_identifier = aws_subnet.private_app_2[*].id
  target_group_arns   = [aws_lb_target_group.backend.arn]
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  depends_on          = [aws_efs_mount_target.nfs]
  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }
}

output "public_alb_dns"    { value = aws_lb.public.dns_name }
output "database_endpoint" { value = aws_db_instance.postgres.endpoint }
