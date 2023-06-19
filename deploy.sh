#!/bin/bash

docker build -t springapp .

docker tag springapp:latest 475154562783.dkr.ecr.us-east-1.amazonaws.com/producao:latest

cd terraform

terraform init

terraform apply -auto-approve
