output "apprunner_service_url" {
  value = "https://${aws_apprunner_service.service.service_url}"
}
