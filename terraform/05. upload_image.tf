data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "null_resource" "upload_image" {
  triggers = {
    order = aws_ecr_repository.springapp.id
  }
  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${aws_ecr_repository.springapp.repository_url} && docker push ${aws_ecr_repository.springapp.repository_url}:latest && sleep 20"
  }
}
