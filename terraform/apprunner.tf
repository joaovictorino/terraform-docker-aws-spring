data "aws_iam_policy_document" "apprunner-service-assume-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["build.apprunner.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apprunner-service-role" {
  name               = "SpringAppRunnerECRAccessRole"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.apprunner-service-assume-policy.json
}

resource "aws_iam_role_policy_attachment" "apprunner-service-role-attachment" {
  role       = aws_iam_role.apprunner-service-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

data "aws_iam_policy_document" "apprunner-instance-assume-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["tasks.apprunner.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apprunner-instance-role" {
  name               = "SpringAppRunnerInstanceRole"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.apprunner-instance-assume-policy.json
}

resource "aws_apprunner_vpc_connector" "connector" {
  vpc_connector_name = "name"
  subnets            = aws_subnet.private_subnet.*.id
  security_groups    = [aws_security_group.ecs_service.id]
}

resource "aws_apprunner_service" "service" {
  service_name = "apprunner-petclinic"
  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner-service-role.arn
    }
    image_repository {
      image_configuration {
        port = 80
        runtime_environment_variables = {
          "MYSQL_URL" : "jdbc:mysql://${aws_db_instance.rds.address}/petclinic",
          "MYSQL_USER" : "petclinic",
          "MYSQL_PASS" : "petclinic"
        }
      }
      image_identifier      = "${aws_ecr_repository.springapp.repository_url}:latest"
      image_repository_type = "ECR"
    }
  }
  instance_configuration {
    instance_role_arn = aws_iam_role.apprunner-instance-role.arn
  }

  network_configuration {
    egress_configuration {
      egress_type       = "VPC"
      vpc_connector_arn = aws_apprunner_vpc_connector.connector.arn
    }
  }

  depends_on = [null_resource.upload_image]
}
