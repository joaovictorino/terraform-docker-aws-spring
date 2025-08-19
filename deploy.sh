#!/bin/bash

docker build -t springapp .

aws_account_id=$(aws sts get-caller-identity --query Account --output text)
docker tag springapp:latest $aws_account_id.dkr.ecr.us-east-1.amazonaws.com/springapp:latest

cd terraform

terraform init

terraform apply -auto-approve
