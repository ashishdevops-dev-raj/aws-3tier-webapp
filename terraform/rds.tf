# =====================================================================
# RDS Subnet Group — RDS requires subnets in at least 2 AZs
# =====================================================================
resource "aws_db_subnet_group" "mysql" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${local.name_prefix}-db-subnet-group" }
}

# =====================================================================
# MySQL 8.0 — Free Tier eligible (db.t3.micro / 20 GB / single-AZ)
# =====================================================================
resource "aws_db_instance" "mysql" {
  identifier             = "${local.name_prefix}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  storage_type           = "gp2"
  storage_encrypted      = true

  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  port                   = 3306

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 0      # 0 = no automated backups (Free Tier cost saver)
  skip_final_snapshot     = true   # set to false for production
  deletion_protection     = false  # set to true for production

  apply_immediately = true

  tags = {
    Name = "${local.name_prefix}-mysql"
    Tier = "data"
  }
}
