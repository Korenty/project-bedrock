# ==============================================================================
# PHASE 3: MANAGED DATA LAYER (DATABASES)
# ==============================================================================
# This configuration provisions high-availability, private databases for the
# retail store microservices: MySQL (Catalog), PostgreSQL (Orders), and 
# DynamoDB (Carts). All credentials are secure and stored in Secrets Manager.

# ------------------------------------------------------------------------------
# 1. DATABASE CREDENTIALS GENERATION (Secrets & Safety)
# ------------------------------------------------------------------------------
# Generates secure, random passwords so we never hardcode secrets in Git.

resource "random_password" "mysql_password" {
  length           = 16
  special          = true
  override_special = "-_"
}

resource "random_password" "postgres_password" {
  length           = 16
  special          = true
  override_special = "-_"
}

# ------------------------------------------------------------------------------
# 2. SECURITY GROUPS (Strict Network Isolation)
# ------------------------------------------------------------------------------
# Creates firewall rules that allow database traffic ONLY from the EKS nodes.

resource "aws_security_group" "mysql_sg" {
  name        = "project-bedrock-mysql-sg"
  description = "Allow inbound MySQL traffic from EKS worker nodes only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "project-bedrock-mysql-sg"
    Project = "karatu-2025-capstone"
  }
}

resource "aws_security_group" "postgres_sg" {
  name        = "project-bedrock-postgres-sg"
  description = "Allow inbound PostgreSQL traffic from EKS worker nodes only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "project-bedrock-postgres-sg"
    Project = "karatu-2025-capstone"
  }
}

# ------------------------------------------------------------------------------
# 3. RDS SUBNET GROUP (Private Deployment Placement)
# ------------------------------------------------------------------------------
# Groups our private subnets together so AWS knows where to safely place the databases.

resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "project-bedrock-rds-subnet-group"
  description = "Database subnet group placed inside private subnets"
  subnet_ids  = module.vpc.private_subnets

  tags = {
    Name    = "project-bedrock-rds-subnet-group"
    Project = "karatu-2025-capstone"
  }
}

# ------------------------------------------------------------------------------
# 4. AMAZON RDS MYSQL (Catalog Service Database)
# ------------------------------------------------------------------------------
resource "aws_db_instance" "mysql" {
  identifier             = "bedrock-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro" # Complying with Student/Free-Tier limits
  allocated_storage      = 20
  max_allocated_storage  = 50
  db_name                = "catalog"
  username               = "catalog_user"
  password               = random_password.mysql_password.result
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]
  skip_final_snapshot    = true

  tags = {
    Name    = "bedrock-mysql-db"
    Project = "karatu-2025-capstone"
  }
}

# ------------------------------------------------------------------------------
# 5. AMAZON RDS POSTGRESQL (Orders Service Database)
# ------------------------------------------------------------------------------
resource "aws_db_instance" "postgres" {
  identifier = "bedrock-postgres"
  engine     = "postgres"
  # FIXED: Specifying major version '15' so AWS dynamically selects the most modern,
  # available minor patch release in the target region (resolves 15.4 deprecation).
  engine_version         = "15"
  instance_class         = "db.t3.micro" # Complying with Student/Free-Tier limits
  allocated_storage      = 20
  max_allocated_storage  = 50
  db_name                = "orders"
  username               = "orders_user"
  password               = random_password.postgres_password.result
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
  skip_final_snapshot    = true

  tags = {
    Name    = "bedrock-postgres-db"
    Project = "karatu-2025-capstone"
  }
}

# ------------------------------------------------------------------------------
# 6. AMAZON DYNAMODB (Carts Service NoSQL Store)
# ------------------------------------------------------------------------------
# Uses "PAY_PER_REQUEST" to ensure cost is $0 when not actively serving requests.

resource "aws_dynamodb_table" "carts_table" {
  name         = "items" # Standard table name expected by the retail carts service
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name    = "project-bedrock-carts-table"
    Project = "karatu-2025-capstone"
  }
}

# ------------------------------------------------------------------------------
# 7. AWS SECRETS MANAGER (Centralized Credentials Store)
# ------------------------------------------------------------------------------
# Automatically stores DB hostnames, users, and passwords for microservice ingestion.

resource "aws_secretsmanager_secret" "db_secrets" {
  name                    = "project-bedrock-db-secrets"
  recovery_window_in_days = 0 # Forces deletion upon terraform destroy (prevents naming locks)

  tags = {
    Project = "karatu-2025-capstone"
  }
}

resource "aws_secretsmanager_secret_version" "db_secrets_val" {
  secret_id = aws_secretsmanager_secret.db_secrets.id
  secret_string = jsonencode({
    mysql_host     = aws_db_instance.mysql.address
    mysql_port     = 3306
    mysql_user     = "catalog_user"
    mysql_password = random_password.mysql_password.result
    mysql_database = "catalog"

    postgres_host     = aws_db_instance.postgres.address
    postgres_port     = 5432
    postgres_user     = "orders_user"
    postgres_password = random_password.postgres_password.result
    postgres_database = "orders"
  })
}

# ------------------------------------------------------------------------------
# 8. OUTPUTS (To assist Helm setup in Phase 6)
# ------------------------------------------------------------------------------
output "mysql_endpoint" {
  value = aws_db_instance.mysql.endpoint
}

output "postgres_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.carts_table.name
}