#!/bin/bash

apt update
apt install -y git
apt install -y curl
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
git clone https://github.com/StyriaAI/mnist_api.git
# We shouldn't build in production, instead we'll use a registry
#docker build -t mnist .
docker pull 127.0.0.1:5000/mnist
docker swarm init
docker stack deploy -c mnist-app-stack.yml mnist-app
