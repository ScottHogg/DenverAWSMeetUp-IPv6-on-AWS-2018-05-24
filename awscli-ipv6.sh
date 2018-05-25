#!/bin/bash

# Based on bash scripts from:
# https://medium.com/@brad.simonin/create-an-aws-vpc-and-subnet-using-the-aws-cli-and-bash-a92af4d2e54b

# Variables used in this script:
availabilityZone1="us-west-2a"
availabilityZone2="us-west-2b"
vpcName="Newv6VPC"
subnetName1="v6Subnet1"
subnetName2="v6Subnet2"
gatewayName="Newv6VPCInternetGateway"
routeTableName="v6RouteTable"
vpcCidrBlock="10.50.0.0/16"
subNetCidrBlock1="10.50.10.0/24"
subNetCidrBlock2="10.50.20.0/24"

# Create a VPC with an IPv4 CIDR block and allocate an AWS IPv6 /56 Prefix
echo "Creating VPC ..."
aws_response=$(aws ec2 create-vpc --cidr-block "$vpcCidrBlock" --amazon-provided-ipv6-cidr-block --output json)
# Capture the VPC ID in a variable
vpcId=$(echo -e "$aws_response" | /usr/bin/jq '.Vpc.VpcId' | tr -d '"')
echo "VPC ID ... $vpcId"
# Capture the VPC's IPv6 CIDR
#vpcV6CIDR=$(echo -e "$aws_response" | /usr/bin/jq '.Vpc.Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock' | tr -d '"')
vpcV6CIDR=$(aws ec2 describe-vpcs --query "Vpcs[?VpcId == '$vpcId'].Ipv6CidrBlockAssociationSet[0].Ipv6CidrBlock" --output text)
echo "VPC IPv6 CIDR ... $vpcV6CIDR"
# Enable DNS for the VPC
modify_response=$(aws ec2 modify-vpc-attribute --vpc-id "$vpcId" --enable-dns-support "{\"Value\":true}")
modify_response=$(aws ec2 modify-vpc-attribute --vpc-id "$vpcId" --enable-dns-hostnames "{\"Value\":true}")
# Give the VPC a Name tag
aws ec2 create-tags --resources "$vpcId" --tags Key=Name,Value="$vpcName"
# Describe the VPC
echo "VPC Info ..."
aws ec2 describe-vpcs --vpc-id "$vpcId"

# Determine the subnet /64s from the VPC's /56
echo "IPv6 Prefix ..."
echo $vpcV6CIDR
[[ "$vpcV6CIDR" =~ ^([^-]+)00::(.*)$ ]] && v6prefix="${BASH_REMATCH[1]}"
echo $v6prefix


# Create IGW for IPv4 and attach it to VPC and create default route table for VPC
echo "Creating IGW ..."
gateway_response=$(aws ec2 create-internet-gateway --output json)
gatewayId=$(echo -e "$gateway_response" |  /usr/bin/jq '.InternetGateway.InternetGatewayId' | tr -d '"')
# Give the IGW a Name tag
aws ec2 create-tags --resources "$gatewayId" --tags Key=Name,Value="$gatewayName"
# Associate the IGW to the VPC
attach_response=$(aws ec2 attach-internet-gateway --internet-gateway-id "$gatewayId" --vpc-id "$vpcId")
# Describe the IGW
echo "IGW Info ..."
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values="$vpcId""

# Create EOIGW
echo "Creating EOIGW ..."
aws ec2 create-egress-only-internet-gateway --vpc-id "$vpcId"
# Describe the EOIGW
echo "EOIGW Info ..."
aws ec2 describe-egress-only-internet-gateways

# Create 2 subnets and add IPv6 CIDR blocks to the subnets in the VPC
echo "Creating Subnets ..."
subnet_response1=$(aws ec2 create-subnet --cidr-block "$subNetCidrBlock1" --ipv6-cidr-block "$v6prefix"10::/64 \
 --availability-zone "$availabilityZone1" --vpc-id "$vpcId"  --output json)
subnetId1=$(echo -e "$subnet_response1" | /usr/bin/jq '.Subnet.SubnetId' | tr -d '"')
echo $subnetId1
subnet_response2=$(aws ec2 create-subnet --cidr-block "$subNetCidrBlock2" --ipv6-cidr-block "$v6prefix"20::/64 \
 --availability-zone "$availabilityZone2" --vpc-id "$vpcId"  --output json)
subnetId2=$(echo -e "$subnet_response2" | /usr/bin/jq '.Subnet.SubnetId' | tr -d '"')
echo $subnetId2
# Give the subnets Name tags
aws ec2 create-tags --resources "$subnetId1" --tags Key=Name,Value="$subnetName1"
aws ec2 create-tags --resources "$subnetId2" --tags Key=Name,Value="$subnetName2"
aws ec2 describe-subnets --filters "Name=tag:Name,Values=v6Subnet1" --output text | awk '{print $9}' | grep subnet
aws ec2 describe-subnets --filters "Name=tag:Name,Values=v6Subnet2" --output text | awk '{print $9}' | grep subnet
# Enable public IPv4s on public subnets
modify_response=$(aws ec2 modify-subnet-attribute --subnet-id "$subnetId1" --map-public-ip-on-launch)
modify_response=$(aws ec2 modify-subnet-attribute --subnet-id "$subnetId2" --map-public-ip-on-launch)
# Assign IPv6 address on creation of EC2 instances
modify_response=$(aws ec2 modify-subnet-attribute --subnet-id "$subnetId1" --assign-ipv6-address-on-creation)
modify_response=$(aws ec2 modify-subnet-attribute --subnet-id "$subnetId2" --assign-ipv6-address-on-creation)
# Describe the Subnets
echo "Subnet Info ..."
aws ec2 describe-subnets --filters "Name=tag:Name,Values="$subnetName1"" --output text
aws ec2 describe-subnets --filters "Name=tag:Name,Values="$subnetName2"" --output text

# Create a Public Route Table for this VPC Subnets
route_table_response=$(aws ec2 create-route-table --vpc-id "$vpcId" --output json)
routeTableId=$(echo -e "$route_table_response" | /usr/bin/jq '.RouteTable.RouteTableId' | tr -d '"')
# Give the route table a Name tag
aws ec2 create-tags --resources "$routeTableId" --tags Key=Name,Value="$routeTableName"
# Add IPv4 default route for the internet gateway
route_responsev4=$(aws ec2 create-route --route-table-id "$routeTableId" --destination-cidr-block 0.0.0.0/0 --gateway-id "$gatewayId")
# Add IPv6 default route to IGW - for public subnet
route_responsev6=$(aws ec2 create-route --route-table-id "$routeTableId" --destination-ipv6-cidr-block ::/0 --gateway-id "$gatewayId")
# Associate Route Table to subnets
associate_response=$(aws ec2 associate-route-table --subnet-id "$subnetId1" --route-table-id "$routeTableId")
associate_response=$(aws ec2 associate-route-table --subnet-id "$subnetId2" --route-table-id "$routeTableId")
# Show the route table
echo "Route Table Info ..."
aws ec2 describe-route-tables --route-table-id "$routeTableId"

echo "End of Script"