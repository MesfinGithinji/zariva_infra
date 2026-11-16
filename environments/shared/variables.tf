variable "vpc_id" {
  description = "My existing VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of my private subnet IDs"
  type        = list(string)
}

variable "runner_sg_id" {
  description = "The security group ID of my existing self-hosted runner EC2"
  type        = string
}

variable "db_master_password" {
  description = "Master password for the shared PostgreSQL database"
  type        = string
  sensitive   = true
}