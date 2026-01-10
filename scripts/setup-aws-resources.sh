#!/bin/bash
# Script to set up AWS resources for microservices deployment

set -e

AWS_REGION="us-east-1"
VPC_CIDR="10.0.0.0/16"
CLUSTER_NAME="dissertation-cluster"

echo "Creating VPC and networking resources..."

# Create VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --query 'Vpc.VpcId' --output text)
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=dissertation-vpc
echo "VPC created: $VPC_ID"

# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=dissertation-igw
echo "Internet Gateway created: $IGW_ID"

# Create public subnets
PUBLIC_SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 \
  --availability-zone ${AWS_REGION}a --query 'Subnet.SubnetId' --output text)
PUBLIC_SUBNET_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 \
  --availability-zone ${AWS_REGION}b --query 'Subnet.SubnetId' --output text)

# Create private subnets
PRIVATE_SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.3.0/24 \
  --availability-zone ${AWS_REGION}a --query 'Subnet.SubnetId' --output text)
PRIVATE_SUBNET_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.4.0/24 \
  --availability-zone ${AWS_REGION}b --query 'Subnet.SubnetId' --output text)

echo "Subnets created:"
echo "  Public: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "  Private: $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2"

# Create route table for public subnets
PUBLIC_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PUBLIC_RT --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_1 --route-table-id $PUBLIC_RT
aws ec2 associate-route-table --subnet-id $PUBLIC_SUBNET_2 --route-table-id $PUBLIC_RT

# Allocate Elastic IP for NAT Gateway
EIP=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)

# Create NAT Gateway
NAT_GW=$(aws ec2 create-nat-gateway --subnet-id $PUBLIC_SUBNET_1 --allocation-id $EIP \
  --query 'NatGateway.NatGatewayId' --output text)
echo "Waiting for NAT Gateway to be available..."
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_GW

# Create route table for private subnets
PRIVATE_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PRIVATE_RT --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_GW
aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_1 --route-table-id $PRIVATE_RT
aws ec2 associate-route-table --subnet-id $PRIVATE_SUBNET_2 --route-table-id $PRIVATE_RT

echo "NAT Gateway created: $NAT_GW"

# Create security groups
ALB_SG=$(aws ec2 create-security-group --group-name dissertation-alb-sg \
  --description "Security group for ALB" --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

ECS_SG=$(aws ec2 create-security-group --group-name dissertation-ecs-sg \
  --description "Security group for ECS tasks" --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

RDS_SG=$(aws ec2 create-security-group --group-name dissertation-rds-sg \
  --description "Security group for RDS" --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

REDIS_SG=$(aws ec2 create-security-group --group-name dissertation-redis-sg \
  --description "Security group for Redis" --vpc-id $VPC_ID \
  --query 'GroupId' --output text)

# Configure security group rules
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $ALB_SG --protocol tcp --port 443 --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress --group-id $ECS_SG --protocol tcp --port 8080 --source-group $ALB_SG
aws ec2 authorize-security-group-ingress --group-id $ECS_SG --protocol tcp --port 8081 --source-group $ECS_SG
aws ec2 authorize-security-group-ingress --group-id $ECS_SG --protocol tcp --port 8082 --source-group $ECS_SG
aws ec2 authorize-security-group-ingress --group-id $ECS_SG --protocol tcp --port 8083 --source-group $ECS_SG
aws ec2 authorize-security-group-ingress --group-id $ECS_SG --protocol tcp --port 8084 --source-group $ECS_SG

aws ec2 authorize-security-group-ingress --group-id $RDS_SG --protocol tcp --port 5432 --source-group $ECS_SG
aws ec2 authorize-security-group-ingress --group-id $REDIS_SG --protocol tcp --port 6379 --source-group $ECS_SG

echo "Security groups created:"
echo "  ALB: $ALB_SG"
echo "  ECS: $ECS_SG"
echo "  RDS: $RDS_SG"
echo "  Redis: $REDIS_SG"

# Create ECR repositories
echo "Creating ECR repositories..."
for repo in api-gateway user-service order-service payment-service notification-service; do
  aws ecr create-repository --repository-name $repo --region $AWS_REGION || echo "Repository $repo may already exist"
done

# Create ECS cluster
echo "Creating ECS cluster..."
aws ecs create-cluster --cluster-name $CLUSTER_NAME \
  --capacity-providers FARGATE \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1

# Create CloudWatch log groups
echo "Creating CloudWatch log groups..."
for service in api-gateway user-service order-service payment-service notification-service; do
  aws logs create-log-group --log-group-name /ecs/$service --region $AWS_REGION || echo "Log group /ecs/$service may already exist"
done

echo "Setup complete!"
echo "VPC ID: $VPC_ID"
echo "Public Subnets: $PUBLIC_SUBNET_1, $PUBLIC_SUBNET_2"
echo "Private Subnets: $PRIVATE_SUBNET_1, $PRIVATE_SUBNET_2"
echo "Save these values for later use!"

