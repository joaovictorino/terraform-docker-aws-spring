output "apprunner_service_url" {
  value = "https://${aws_apprunner_service.service.service_url}"
}

output "ecs_url" {
  value = "http://${aws_alb.alb_springapp.dns_name}"
}
