#!/bin/bash
# Terraform Import Script for GreenRoad
# Run this after: terraform init

set -e

echo "=== GreenRoad Terraform Import Script ==="
echo ""

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "Running terraform init first..."
    terraform init
fi

echo "Fetching existing resource IDs from AWS..."
echo ""

# Get resource IDs
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=greenroad-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=greenroad-igw" --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null || echo "None")
SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=greenroad-public-subnet" --query 'Subnets[0].SubnetId' --output text 2>/dev/null || echo "None")
RTB_ID=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=greenroad-public-rt" --query 'RouteTables[0].RouteTableId' --output text 2>/dev/null || echo "None")
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=greenroad-sg" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")
INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=greenroad-minikube" "Name=instance-state-name,Values=running,pending,stopped" --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "None")
EIP_ID=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=greenroad-eip" --query 'Addresses[0].AllocationId' --output text 2>/dev/null || echo "None")
KEY_NAME=$(aws ec2 describe-key-pairs --filters "Name=key-name,Values=greenroad-key" --query 'KeyPairs[0].KeyName' --output text 2>/dev/null || echo "None")
IAM_ROLE=$(aws iam get-role --role-name greenroad-ec2-role --query 'Role.RoleName' --output text 2>/dev/null || echo "None")
IAM_PROFILE=$(aws iam get-instance-profile --instance-profile-name greenroad-ec2-profile --query 'InstanceProfile.InstanceProfileName' --output text 2>/dev/null || echo "None")
LOG_GROUP=$(aws logs describe-log-groups --log-group-name-prefix "/greenroad/app" --query 'logGroups[0].logGroupName' --output text 2>/dev/null || echo "None")

echo "Found resources:"
echo "  VPC:              $VPC_ID"
echo "  Internet Gateway: $IGW_ID"
echo "  Subnet:           $SUBNET_ID"
echo "  Route Table:      $RTB_ID"
echo "  Security Group:   $SG_ID"
echo "  EC2 Instance:     $INSTANCE_ID"
echo "  Elastic IP:       $EIP_ID"
echo "  Key Pair:         $KEY_NAME"
echo "  IAM Role:         $IAM_ROLE"
echo "  IAM Profile:      $IAM_PROFILE"
echo "  Log Group:        $LOG_GROUP"
echo ""

echo "=== Starting Import ==="
echo ""

# Import VPC
if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ] && [ -n "$VPC_ID" ]; then
    echo "Importing VPC: $VPC_ID"
    terraform import aws_vpc.main $VPC_ID || echo "  -> Already imported or error"
fi

# Import Internet Gateway
if [ "$IGW_ID" != "None" ] && [ "$IGW_ID" != "null" ] && [ -n "$IGW_ID" ]; then
    echo "Importing Internet Gateway: $IGW_ID"
    terraform import aws_internet_gateway.main $IGW_ID || echo "  -> Already imported or error"
fi

# Import Subnet
if [ "$SUBNET_ID" != "None" ] && [ "$SUBNET_ID" != "null" ] && [ -n "$SUBNET_ID" ]; then
    echo "Importing Subnet: $SUBNET_ID"
    terraform import aws_subnet.public $SUBNET_ID || echo "  -> Already imported or error"
fi

# Import Route Table
if [ "$RTB_ID" != "None" ] && [ "$RTB_ID" != "null" ] && [ -n "$RTB_ID" ]; then
    echo "Importing Route Table: $RTB_ID"
    terraform import aws_route_table.public $RTB_ID || echo "  -> Already imported or error"
    
    # Import Route Table Association
    echo "Importing Route Table Association..."
    terraform import aws_route_table_association.public $SUBNET_ID/$RTB_ID || echo "  -> Already imported or error"
fi

# Import Security Group
if [ "$SG_ID" != "None" ] && [ "$SG_ID" != "null" ] && [ -n "$SG_ID" ]; then
    echo "Importing Security Group: $SG_ID"
    terraform import aws_security_group.minikube $SG_ID || echo "  -> Already imported or error"
fi

# Import Key Pair
if [ "$KEY_NAME" != "None" ] && [ "$KEY_NAME" != "null" ] && [ -n "$KEY_NAME" ]; then
    echo "Importing Key Pair: $KEY_NAME"
    terraform import aws_key_pair.main $KEY_NAME || echo "  -> Already imported or error"
fi

# Import IAM Role
if [ "$IAM_ROLE" != "None" ] && [ "$IAM_ROLE" != "null" ] && [ -n "$IAM_ROLE" ]; then
    echo "Importing IAM Role: $IAM_ROLE"
    terraform import aws_iam_role.ec2_role $IAM_ROLE || echo "  -> Already imported or error"
    
    # Import IAM policies
    echo "Importing IAM Policies..."
    terraform import aws_iam_role_policy.ecr_policy greenroad-ec2-role:greenroad-ecr-policy || echo "  -> Already imported or error"
    terraform import aws_iam_role_policy.cloudwatch_policy greenroad-ec2-role:greenroad-cloudwatch-policy || echo "  -> Already imported or error"
fi

# Import IAM Instance Profile
if [ "$IAM_PROFILE" != "None" ] && [ "$IAM_PROFILE" != "null" ] && [ -n "$IAM_PROFILE" ]; then
    echo "Importing IAM Instance Profile: $IAM_PROFILE"
    terraform import aws_iam_instance_profile.ec2_profile $IAM_PROFILE || echo "  -> Already imported or error"
fi

# Import EC2 Instance
if [ "$INSTANCE_ID" != "None" ] && [ "$INSTANCE_ID" != "null" ] && [ -n "$INSTANCE_ID" ]; then
    echo "Importing EC2 Instance: $INSTANCE_ID"
    terraform import aws_instance.minikube $INSTANCE_ID || echo "  -> Already imported or error"
fi

# Import Elastic IP
if [ "$EIP_ID" != "None" ] && [ "$EIP_ID" != "null" ] && [ -n "$EIP_ID" ]; then
    echo "Importing Elastic IP: $EIP_ID"
    terraform import aws_eip.main $EIP_ID || echo "  -> Already imported or error"
fi

# Import CloudWatch Log Group
if [ "$LOG_GROUP" != "None" ] && [ "$LOG_GROUP" != "null" ] && [ -n "$LOG_GROUP" ]; then
    echo "Importing CloudWatch Log Group: $LOG_GROUP"
    terraform import aws_cloudwatch_log_group.main $LOG_GROUP || echo "  -> Already imported or error"
fi

echo ""
echo "=== Import Complete ==="
echo ""
echo "Next steps:"
echo "  1. Run: terraform plan"
echo "  2. Review changes (should show minimal or no changes)"
echo "  3. Run: terraform apply (if needed)"
echo ""
