#!/bin/bash

apt-get update
apt-get install -y git
apt-get install -y curl
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
docker pull tensorflow/serving:1.8.0
git clone https://github.com/StyriaAI/mnist_model.git
docker swarm init
