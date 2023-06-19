resource "aws_cloudwatch_log_group" "springapp" {
  name = "springapp"
}

resource "aws_ecr_repository" "springapp" {
  name = "springapp"
  force_delete = true
}

resource "aws_ecs_cluster" "cluster" {
  name = "production-ecs-cluster"
}

data "template_file" "web_task" {
  template = file("web_task_definition.json")

  vars = {
    image        = aws_ecr_repository.springapp.repository_url
    log_group    = aws_cloudwatch_log_group.springapp.name
    mysql_url    = "jdbc:mysql://${aws_db_instance.rds.address}:3306/petclinic"
    mysql_user   = "petclinic"
    mysql_pass   = "petclinic"
  }
}

resource "aws_ecs_task_definition" "web" {
  family                   = "spring_web"
  container_definitions    = data.template_file.web_task.rendered
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
}

resource "random_id" "target_group_sufix" {
  byte_length = 2
}

resource "aws_alb_target_group" "alb_target_group" {
  name        = "production-alb-target-group-${random_id.target_group_sufix.hex}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc.id
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "web_inbound_sg" {
  name        = "production-web-inbound-sg"
  description = "Allow HTTP from Anywhere into ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "alb_springapp" {
  name            = "production-alb-springapp"
  subnets         = [aws_subnet.public_subnet.0.id, aws_subnet.public_subnet.1.id]
  security_groups = [aws_security_group.default.id, aws_security_group.web_inbound_sg.id]
}

resource "aws_alb_listener" "springapp" {
  load_balancer_arn = aws_alb.alb_springapp.arn
  port              = "80"
  protocol          = "HTTP"
  depends_on        = [aws_alb_target_group.alb_target_group]

  default_action {
    target_group_arn = aws_alb_target_group.alb_target_group.arn
    type             = "forward"
  }
}

data "aws_iam_policy_document" "ecs_service_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_role" {
  name               = "ecs_role"
  assume_role_policy = data.aws_iam_policy_document.ecs_service_role.json
}

data "aws_iam_policy_document" "ecs_service_policy" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "ec2:Describe*",
      "ec2:AuthorizeSecurityGroupIngress"
    ]
  }
}

resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name   = "ecs_service_role_policy"
  policy = data.aws_iam_policy_document.ecs_service_policy.json
  role   = aws_iam_role.ecs_role.id
}

resource "aws_iam_role" "ecs_execution_role" {
  name               = "ecs_task_execution_role"
  assume_role_policy = file("ecs-task-execution-role.json")
}

resource "aws_iam_role_policy" "ecs_execution_role_policy" {
  name   = "ecs_execution_role_policy"
  policy = file("ecs-execution-role-policy.json")
  role   = aws_iam_role.ecs_execution_role.id
}

resource "aws_security_group" "ecs_service" {
  vpc_id      = aws_vpc.vpc.id
  name        = "production-ecs-service-sg"
  description = "Allow egress from container"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ecs_task_definition" "web" {
  task_definition = aws_ecs_task_definition.web.family
}

resource "aws_ecs_service" "web" {
  name            = "production-web"
  task_definition = "${aws_ecs_task_definition.web.family}:${max("${aws_ecs_task_definition.web.revision}", "${data.aws_ecs_task_definition.web.revision}")}"
  desired_count   = 2
  launch_type     = "FARGATE"
  cluster         = aws_ecs_cluster.cluster.id

  network_configuration {
    security_groups = [aws_security_group.default.id, aws_security_group.ecs_service.id]
    subnets         = [aws_subnet.private_subnet.0.id, aws_subnet.private_subnet.1.id]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.alb_target_group.arn
    container_name   = "web"
    container_port   = "80"
  }

  depends_on = [aws_alb_target_group.alb_target_group, aws_iam_role_policy.ecs_service_role_policy]
}

#resource "aws_iam_role" "ecs_autoscale_role" {
#  name               = "${var.environment}_ecs_autoscale_role"
#  assume_role_policy = "${file("${path.module}/policies/ecs-autoscale-role.json")}"
#}
#
#resource "aws_iam_role_policy" "ecs_autoscale_role_policy" {
#  name   = "ecs_autoscale_role_policy"
#  policy = "${file("${path.module}/policies/ecs-autoscale-role-policy.json")}"
#  role   = "${aws_iam_role.ecs_autoscale_role.id}"
#}
#
#resource "aws_appautoscaling_target" "target" {
#  service_namespace  = "ecs"
#  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.web.name}"
#  scalable_dimension = "ecs:service:DesiredCount"
#  role_arn           = "${aws_iam_role.ecs_autoscale_role.arn}"
#  min_capacity       = 2
#  max_capacity       = 4
#}
#
#resource "aws_appautoscaling_policy" "up" {
#  name                    = "${var.environment}_scale_up"
#  service_namespace       = "ecs"
#  resource_id             = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.web.name}"
#  scalable_dimension      = "ecs:service:DesiredCount"
#
#
#  step_scaling_policy_configuration {
#    adjustment_type         = "ChangeInCapacity"
#    cooldown                = 60
#    metric_aggregation_type = "Maximum"
#
#    step_adjustment {
#      metric_interval_lower_bound = 0
#      scaling_adjustment = 1
#    }
#  }
#
#  depends_on = ["aws_appautoscaling_target.target"]
#}
#
#resource "aws_appautoscaling_policy" "down" {
#  name                    = "${var.environment}_scale_down"
#  service_namespace       = "ecs"
#  resource_id             = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.web.name}"
#  scalable_dimension      = "ecs:service:DesiredCount"
#
#  step_scaling_policy_configuration {
#    adjustment_type         = "ChangeInCapacity"
#    cooldown                = 60
#    metric_aggregation_type = "Maximum"
#
#    step_adjustment {
#      metric_interval_lower_bound = 0
#      scaling_adjustment = -1
#    }
#  }
#
#  depends_on = ["aws_appautoscaling_target.target"]
#} 
#
#resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
#  alarm_name          = "${var.environment}_openjobs_web_cpu_utilization_high"
#  comparison_operator = "GreaterThanOrEqualToThreshold"
#  evaluation_periods  = "2"
#  metric_name         = "CPUUtilization"
#  namespace           = "AWS/ECS"
#  period              = "60"
#  statistic           = "Maximum"
#  threshold           = "85"
#
#  dimensions {
#    ClusterName = "${aws_ecs_cluster.cluster.name}"
#    ServiceName = "${aws_ecs_service.web.name}"
#  }
#
#  alarm_actions = ["${aws_appautoscaling_policy.up.arn}"]
#  ok_actions    = ["${aws_appautoscaling_policy.down.arn}"]
#}
