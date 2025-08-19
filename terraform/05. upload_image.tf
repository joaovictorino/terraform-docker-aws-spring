resource "null_resource" "upload_image" {
  triggers = {
    order = aws_ecr_repository.springapp.id
  }
  provisioner "local-exec" {
    command = "aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 475154562783.dkr.ecr.us-east-1.amazonaws.com && docker push 475154562783.dkr.ecr.us-east-1.amazonaws.com/springapp:latest && sleep 20"
  }
}
