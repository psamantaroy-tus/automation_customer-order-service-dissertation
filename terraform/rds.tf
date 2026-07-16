# Two managed MySQL databases (mirrors the manual RDS build), plus a security
# group that allows port 3306 ONLY from the EKS worker nodes. This automates
# the manual "Stage 8 — Fix Security Groups" step that was easy to miss.

resource "aws_db_subnet_group" "default" {
  name       = "dissertation-db-subnets"
  subnet_ids = data.aws_subnets.default.ids
  tags       = local.tags
}

resource "aws_security_group" "rds" {
  name        = "rds-sg"
  description = "Allow MySQL (3306) from EKS worker nodes"
  vpc_id      = data.aws_vpc.default.id

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

  tags = local.tags
}

resource "aws_db_instance" "customer" {
  identifier             = "customer-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "customer_db"
  username               = var.db_username
  password               = var.customer_db_password
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true # clean, repeatable teardown
  deletion_protection    = false
  apply_immediately      = true
  tags                   = local.tags
}

resource "aws_db_instance" "order" {
  identifier             = "order-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "order_db"
  username               = var.db_username
  password               = var.order_db_password
  db_subnet_group_name   = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false
  apply_immediately      = true
  tags                   = local.tags
}
