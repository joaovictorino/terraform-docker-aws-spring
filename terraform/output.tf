output "ecs_url" {
  value = "http://${aws_alb.alb_springapp.dns_name}"
}
