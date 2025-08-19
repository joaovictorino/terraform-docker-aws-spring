# Terraform ambiente PaaS na AWS, usando RDS e ECS Fargate

Pré-requisitos

- aws instalado
- Terraform instalado

Logar na AWS usando aws cli com o comando abaixo

```sh
aws configure sso
```

Inicializar o Terraform

```sh
terraform init
```

Compilar a imagem Dockerfile localmente

```sh
docker build -t springapp .
```

Renomear a imagem

```sh
aws_account_id=$(aws sts get-caller-identity --query Account --output text)
docker tag springapp:latest $aws_account_id.dkr.ecr.us-east-1.amazonaws.com/springapp:latest
```

Executar o Terraform

```sh
terraform apply -auto-approve
```
