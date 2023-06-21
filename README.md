# Terraform ambiente PaaS na AWS, usando RDS, ECS Fargate e App Runner

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
docker tag springapp:latest 475154562783.dkr.ecr.us-east-1.amazonaws.com/springapp:latest
```

Executar o Terraform

```sh
terraform apply -auto-approve
```
