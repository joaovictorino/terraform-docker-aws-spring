resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "production-rds-subnet-group"
  subnet_ids = aws_subnet.private_subnet.*.id
}

resource "aws_security_group" "db_access_sg" {
  vpc_id = aws_vpc.vpc.id
  name   = "production-db-access-sg"
}

resource "aws_security_group" "rds_sg" {
  name   = "production-rds-sg"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.db_access_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "rds" {
  identifier             = "production-database"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t2.micro"
  multi_az               = false
  db_name                = "petclinic"
  username               = "petclinic"
  password               = "petclinic"
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.id
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
}
