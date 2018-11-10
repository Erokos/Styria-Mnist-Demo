# Styria-Mnist-Demo
My attempt at deploying an MNIST app using Terraform, AWS and Docker Swarm

# 1. Using Docker Swarm

PREREQUISITES:
1. Swarm Mode on
2. Create a registry for your images so every service has access to them

To deploy this setup locally you first need to initialize the Swarm Mode.

```
docker swarm init
```
Next step is to create a registry:

```
docker service create --name registry --publish 5000:5000 registry
```

Clone the API repository and position yourself to the 'api' subdir to get the Dockerfile for the image:

```
git clone https://github.com/StyriaAI/mnist_api.git && cd mnist_api/api
```

and build the image with the right tag so it's linked to the registry:

```
docker build -t 127.0.0.1:5000/mnist .
```

Push the built image to the registry so it's available to all services and their tasks (containers):

```
docker push 127.0.0.1:5000/mnist 
```

Now, you can get the swarm up and running by executing this command:

```
docker stack deploy -c <name_oy_yaml_file> <name_of_app>
```
which in this case is:

```
docker stack deploy -c mnist-app-stack.yml mnist-app
```
The important file here is the "mnist-app-stack.yml". It's of the same format as a docker compose file with the difference that the stack command will ignore any building of images as it's not recommended to do so in production. That's why it's important to have the registry containing the image already set up. 

The Swarm configuration by default uses the overlay network driver, which is basically a swarm-wide bridge network in which the containers across hosts can access each other (kind of like VLAN). The deploy option is something not present in a normal docker-compose file, it's for using the stack command and specifies options like 'update-config', which describes how to do a service update. In case of updates I don't want the service to go down, also the restart policy makes sure that if the container fails it will automatically restart it. I've also put the services on nodes that have the roles of managers, which can control the swarm. There is a 'delay' option of 10s in the mnist_api service which means it will wait for ten seconds, giving time for the tensorflow service to get created first. 

When updating the services, i.e. changing the specifications in mnist-app-stack.yml, the command you need to run is the same when creating the swarm:

```
docker stack deploy -c mnist-app-stack.yml mnist-app
```

To check your services, one of the commands that gives you info on them and the number of replicas created is:

```
docker stack services mnist-app
```

# 2.Terraform Configuration

PREREQUISITES:
1. Set up an S3 bucket in the region used in the terraform files so the state of the project can be saved.
2. Configure your ssh key pairs

The configuration I've tried to set up is shown in the 'infra2.png' file.

First the VPC is set up within the AWS cloud which that gives us another layer of security since no machine outside this VPC can access our own ones. For this I used the AWS VPC module that can be found on the terraform registry pages. Within it, there are two availability zones set up, with public and private subnets defined as well as the NAT gateway for the private subnets, which also adds to our setup security.

Next, for any production deployment, setting up autoscaling is essential. There are two files for this: 'Autoscaling_mnist_api.tf' and 'Autoscaling_mnist_model.tf'. In both of them, the AWS autoscaling group module was used. 
For the API, http traffic is allowed inbound on ports specified for usage by the api's documentation, also the root device and the elastic block store are set up.
A remote executioner is created to configure the instances for using Docker and initiating the swarm. Here a script from the website: https://get.docker.com/ is used to quickly install the latest docker engine. Although it may not be the safest option, because it installs the edge releases, it's safe enough and rarely produces errors. The API is put on public subnets, an EC2 type healthcheck is set and the scaling options are set which self-evident with descriptive variables, 'min', 'desired' and 'max'.

A similar autoscaling setup is used for the MNIST Model, only it has private subnets connected to the NAT gateway.

The ELB.tf file describes the Elastic Load Balancer, our single point of contact for clients, associated with the API's security group, which will help balance the incoming traffic to the API which will increas the app's availability. A listener is set up to listen on the same ports the API operates on. It will perform a healthcheck every 30s and will timeout after 5s. To be proclaimed healthy or unhealthy, an instance must respond in the same manner (whether ok or not ok) two times in a row.

Lastly, in the 'Dns.tf' the DNS is set and is linked to the ELB so that all traffic goes to it.

The project is still a work in progress but it could be on the right path...
Thank you for reading :)
