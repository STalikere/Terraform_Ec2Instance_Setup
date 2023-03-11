provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "vpc_virginia" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name = "K8s-cluster-vpc"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.vpc_virginia.id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true  
  tags = {
    Name = "K8s-cluster-net"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_virginia.id
  tags = {
     Name = "k8s-cluster-igw"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

resource "aws_route_table" "rt_igw" {
  vpc_id = aws_vpc.vpc_virginia.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
     Name = "K8s-cluster-rtb"
    "kubernetes.io/cluster/kubernetes" = "owned"
  }
}

resource "aws_route_table_association" "subnet_route" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.rt_igw.id
}


resource "aws_security_group" "sg" {
  name = "web-all-traffic"
  vpc_id = aws_vpc.vpc_virginia.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "iam_role" {
  name = "k8s-cluster-iam-master-role_virginia"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
 
}

resource "aws_iam_policy" "iam_policy" {
  name = "k8s-cluster-iam-master-policy-virginia"

   policy = jsonencode({
   "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "ec2:DescribeInstances",
                "ec2:DescribeRegions",
                "ec2:DescribeRouteTables",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVolumes",
                "ec2:CreateSecurityGroup",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:ModifyInstanceAttribute",
                "ec2:ModifyVolume",
                "ec2:AttachVolume",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CreateRoute",
                "ec2:DeleteRoute",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteVolume",
                "ec2:DetachVolume",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DescribeVpcs",
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:AttachLoadBalancerToSubnets",
                "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
                "elasticloadbalancing:CreateLoadBalancer",
                "elasticloadbalancing:CreateLoadBalancerPolicy",
                "elasticloadbalancing:CreateLoadBalancerListeners",
                "elasticloadbalancing:ConfigureHealthCheck",
                "elasticloadbalancing:DeleteLoadBalancer",
                "elasticloadbalancing:DeleteLoadBalancerListeners",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DetachLoadBalancerFromSubnets",
                "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
                "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
                "elasticloadbalancing:AddTags",
                "elasticloadbalancing:CreateListener",
                "elasticloadbalancing:CreateTargetGroup",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:DeleteTargetGroup",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeLoadBalancerPolicies",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
                "iam:CreateServiceLinkedRole",
                "kms:DescribeKey"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "iam_role_policy_attachment" {
  role       = aws_iam_role.iam_role.name
  policy_arn = aws_iam_policy.iam_policy.arn
}

resource "aws_iam_instance_profile" "ec2_launch_configuration_iam_instance_profile" {
  name = "master-role-profile"
  role = aws_iam_role.iam_role.name
}

resource "aws_instance" "k8s-master-node" {
  ami = "ami-0557a15b87f6559cf"
  instance_type = "t2.medium"
  iam_instance_profile = aws_iam_instance_profile.ec2_launch_configuration_iam_instance_profile.name
  subnet_id = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.sg.id]
  associate_public_ip_address = true
  tags = {
     Name = "k8s-master-node"
    "kubernetes.io/cluster/kubernetes" = "owned"
  } 
}