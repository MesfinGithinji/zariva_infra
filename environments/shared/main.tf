locals {
  services     = ["frontend", "backend"]
  environments = toset(["uat", "prod"])
}

# 1. ECR Repositories for Zariva
resource "aws_ecr_repository" "app" {
  for_each             = toset(local.services)
  name                 = "zariva-${each.key}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "cleanup" {
  for_each   = aws_ecr_repository.app
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images for free tier"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 5 }
      action       = { type = "expire" }
    }]
  })
}

# 2. Security Groups (Created inside your existing VPC)
resource "aws_security_group" "alb" {
  for_each    = local.environments
  name        = "zariva-${each.key}-alb-sg"
  description = "Public ALB SG for Zariva ${each.key}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
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

resource "aws_security_group" "ecs_tasks" {
  for_each    = local.environments
  name        = "zariva-${each.key}-ecs-sg"
  description = "Zariva ECS Task SG for ${each.key}"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb[each.key].id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {
  name        = "zariva-rds-sg"
  description = "Zariva RDS Postgres SG"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
    security_groups = [
      aws_security_group.ecs_tasks["uat"].id,
      aws_security_group.ecs_tasks["prod"].id,
      var.runner_sg_id # Allows your existing EC2 runner to connect for migrations
    ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Shared RDS PostgreSQL Instance (Placed in our existing private subnets)
resource "aws_db_subnet_group" "private" {
  name       = "zariva-private-db-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_db_instance" "postgres" {
  identifier             = "zariva-shared-pg"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  storage_type           = "gp3"
  db_name                = "app_prod"
  username               = "postgres_admin"
  password               = var.db_master_password
  db_subnet_group_name   = aws_db_subnet_group.private.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible     = false
  multi_az                = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 0
}