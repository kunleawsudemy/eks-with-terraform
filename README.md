# Create EKS Using Terraform

# Create AWS provider and give it a name provider.tf
```
provider "aws" {
  region = "us-east-1"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}
```

# Create a VPC and give it a name vpc.tf
```
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.vpc_id}"
  }
}
```

# Create Internet Gateway and vige it a name igw.tf
```
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw"
  }
}
```

# Create private and public subnets and name it subnets.tf
```
resource "aws_subnet" "private-us-east-1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/19"
  availability_zone = "us-east-1a"

  tags = {
    "Name"                                      = "private-us-east-1a"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}

resource "aws_subnet" "private-us-east-1b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.32.0/19"
  availability_zone = "us-east-1b"

  tags = {
    "Name"                                      = "private-us-east-1b"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}

resource "aws_subnet" "public-us-east-1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.64.0/19"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    "Name"                                    = "public-us-east-1a"
    "kubernetes.io/role/elb"                  = "1"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}

resource "aws_subnet" "public-us-east-1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.96.0/19"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    "Name"                                      = "public-us-east-1b"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster-name}" = "shared"
  }
}
```
# Create NAT Gateway and name it nat.tf
```
resource "aws_eip" "nat" {
  vpc = true

  tags = {
    Name = "nat"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public-us-east-1a.id

  tags = {
    Name = "nat"
  }

  depends_on = [aws_internet_gateway.igw]
}
```

# Create Route and name it routes.tf
```
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route = [
    {
      cidr_block                 = "0.0.0.0/0"
      nat_gateway_id             = aws_nat_gateway.nat.id
      carrier_gateway_id         = ""
      destination_prefix_list_id = ""
      egress_only_gateway_id     = ""
      gateway_id                 = ""
      instance_id                = ""
      ipv6_cidr_block            = ""
      local_gateway_id           = ""
      network_interface_id       = ""
      transit_gateway_id         = ""
      vpc_endpoint_id            = ""
      vpc_peering_connection_id  = ""
    },
  ]

  tags = {
    Name = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route = [
    {
      cidr_block                 = "0.0.0.0/0"
      gateway_id                 = aws_internet_gateway.igw.id
      nat_gateway_id             = ""
      carrier_gateway_id         = ""
      destination_prefix_list_id = ""
      egress_only_gateway_id     = ""
      instance_id                = ""
      ipv6_cidr_block            = ""
      local_gateway_id           = ""
      network_interface_id       = ""
      transit_gateway_id         = ""
      vpc_endpoint_id            = ""
      vpc_peering_connection_id  = ""
    },
  ]

  tags = {
    Name = "public"
  }
}

resource "aws_route_table_association" "private-us-east-1a" {
  subnet_id      = aws_subnet.private-us-east-1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private-us-east-1b" {
  subnet_id      = aws_subnet.private-us-east-1b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public-us-east-1a" {
  subnet_id      = aws_subnet.public-us-east-1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public-us-east-1b" {
  subnet_id      = aws_subnet.public-us-east-1b.id
  route_table_id = aws_route_table.public.id
}
```

# Create EKS Cluster and name it eks.tf
```
resource "aws_iam_role" "demo" {
  name = "${var.cluster-name}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "demo-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.demo.name
}

resource "aws_eks_cluster" "demo" {
  name     = "${var.cluster-name}"
  role_arn = aws_iam_role.demo.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private-us-east-1a.id,
      aws_subnet.private-us-east-1b.id,
      aws_subnet.public-us-east-1a.id,
      aws_subnet.public-us-east-1b.id
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.demo-AmazonEKSClusterPolicy]
}
```

# Create Managed NodeGroup and name it nodes.tf
```
resource "aws_iam_role" "nodes" {
  name = "eks-node-group-nodes"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodes.name
}

resource "aws_eks_node_group" "private-nodes" {
  cluster_name    = aws_eks_cluster.demo.name
  node_group_name = "${var.node-name}"
  node_role_arn   = aws_iam_role.nodes.arn

  subnet_ids = [
    aws_subnet.public-us-east-1a.id,
    aws_subnet.public-us-east-1b.id
  ]

  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.small"]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 0
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  # taint {
  #   key    = "team"
  #   value  = "devops"
  #   effect = "NO_SCHEDULE"
  # }

  # launch_template {
  #   name    = aws_launch_template.eks-with-disks.name
  #   version = aws_launch_template.eks-with-disks.latest_version
  # }

  depends_on = [
    aws_iam_role_policy_attachment.nodes-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes-AmazonEC2ContainerRegistryReadOnly,
  ]
}

# resource "aws_launch_template" "eks-with-disks" {
#   name = "eks-with-disks"

#   key_name = "local-provisioner"

#   block_device_mappings {
#     device_name = "/dev/xvdb"

#     ebs {
#       volume_size = 50
#       volume_type = "gp2"
#     }
#   }
# }
```

# Create IAM OIDC Provider and name it iam-oidc.tf
```
data "tls_certificate" "eks" {
  url = aws_eks_cluster.demo.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.demo.identity[0].oidc[0].issuer
}
```

# Create a test OpenID connect provider to create an IAM Role and bind it to a test Pod - Name it iam-test.tf
# This policy will be used to list bucket and get bucket location
```
data "aws_iam_policy_document" "test_oidc_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:aws-test"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "test_oidc" {
  assume_role_policy = data.aws_iam_policy_document.test_oidc_assume_role_policy.json
  name               = "test-oidc"
}

resource "aws_iam_policy" "test-policy" {
  name = "test-policy"

  policy = jsonencode({
    Statement = [{
      Action = [
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation"
      ]
      Effect   = "Allow"
      Resource = "arn:aws:s3:::*"
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "test_attach" {
  role       = aws_iam_role.test_oidc.name
  policy_arn = aws_iam_policy.test-policy.arn
}

output "test_policy_arn" {
  value = aws_iam_role.test_oidc.arn
}
```

# Create S3 bucket in the Console to store the Terraform tfstate 

# Define Backend Configuration in Terraform - Name it s3backend.tf
```
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-kjadex"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    #dynamodb_table = "your_dynamodb_table_name"  # Optional for state locking
  }
}
```

# Create IAM Policy and Attach it to the IAM or Role using to create the Cluster
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::terraform-state-bucket-kjadex",
                "arn:aws:s3:::terraform-state-bucket-kjadex/*"
            ]
        }
    ]
}
```

# Now let's Initialize our Terraform Code
```
terraform init
```
# Check For Syntax Error
```
terraform validate
```
# Describes what Terraform will do when you apply your configuration
```
terraform plan
```
# Apply Terraform Configuration Files
```
terraform apply --auto-approve 
```

# List all Clusters Your Region
aws eks list-clusters --region <region-code>

# Export Kubernetes Context
aws eks --region <region-code> update-kubeconfig --name <Cluster-Name>

# Check Nodes Joined The Cluster
kubectl get nodes

# Check Connection To EKS Cluster
kubectl get svc
kubectl get pods -A

# #######################################################

# Now let's create a pod to test IAM roles for service accounts - Name it aws-test-yaml
```
data "aws_iam_policy_document" "test_oidc_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:aws-test"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "test_oidc" {
  assume_role_policy = data.aws_iam_policy_document.test_oidc_assume_role_policy.json
  name               = "test-oidc"
}

resource "aws_iam_policy" "test-policy" {
  name = "test-policy"

  policy = jsonencode({
    Statement = [{
      Action = [
        "s3:ListAllMyBuckets",
        "s3:GetBucketLocation"
      ]
      Effect   = "Allow"
      Resource = "arn:aws:s3:::*"
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "test_attach" {
  role       = aws_iam_role.test_oidc.name
  policy_arn = aws_iam_policy.test-policy.arn
}

output "test_policy_arn" {
  value = aws_iam_role.test_oidc.arn
}
```
# Let's create a Pod to test IAM Roles for Service Account
```
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-test
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::484445038905:role/test-oidc
  
---
apiVersion: v1
kind: Pod
metadata:
  name: aws-cli
  namespace: default
  
spec:
  serviceAccountName: aws-test
  containers:
  - name: aws-cli
    image: amazon/aws-cli
    command: [ "/bin/bash", "-c", "--" ]
    args: [ "while true; do sleep 30; done;" ]
  tolerations:
  - operator: Exists
    effect: NoSchedule
```

# Apply the file
```
kubectl apply -f aws-test.yaml
```

# To see the Service Account
```
kubectl get sa
```

# To see the Service Account Details
```
kubectl describe sa <service-account_name>
```

# Now let's list S3 Buckets in our account
kubectl exec aws-cli -- aws s3api list-buckets

# Create public load balancer and name it deployment.yaml
```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - name: web
          containerPort: 80
        resources:
          requests:
            memory: 256Mi
            cpu: 250m
          limits:
            memory: 256Mi
            cpu: 250m
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: role
                operator: In
                values:
                - general
      # tolerations:
      # - key: team
      #   operator: Equal
      #   value: devops
      #   effect: NoSchedule
```
# Apply the file
```
kubectl apply -f deployment.yaml
```

# To expose the application to the internet, you can create a Kubernetes service of a type load balancer and use annotations to configure load balancer properties.

# Create a file and name it public-lb.yaml
```
---
apiVersion: v1
kind: Service
metadata:
  name: public-lb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: web
```

# Apply the file
```
kubectl apply -f public-lb.yaml
```

# Find load balancer in AWS console. Verify that LB was created in public subnets
# Once the load balancer is in "Active" state, 

[ ] Click "Target Group" on the left pane of EC2 Dashboardand 
[ ] Click the Target Group Name
[ ] Click Targets Tab and you the Health Status of your Instance(s)

[ ] Copy the DNS of the load balancer and paste in a browser, you should see "Welcome to Nginx Page"

--------------------------------------------------------------

# To create private loadbalancer
# Sometimes if you have a large infrastructure with many different services, you have a requirement to expose the application only within your    # VPC. For that, you can create a private load balancer. 

# To make it private, you need additional annotation: aws-load-balancer-internal and then provide the CIDR range. Usually, you use 0.0.0.0/0 to # # allow any services within your VPC to access it.

# Create a file and name it private-lb.yaml
```
---
apiVersion: v1
kind: Service
metadata:
  name: private-lb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-internal: 0.0.0.0/0
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: web
```

# Apply the file
```
kubectl apply -f private-lb.yaml
```
# Find load balancer in AWS console. Verify that the LB was created in private subnets

### ------------------------------------------------ ##
# Now let's Deploy EKS cluster autoscaler (The code needs an adjustment)
### ------------------------------------------------ ##

# We will be using OpenID connect provider to create an IAM role and bind it with the autoscaller.

# Create a file and name it iam-autoscaler.tf
```
data "aws_iam_policy_document" "eks_cluster_autoscaler_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_cluster_autoscaler" {
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_autoscaler_assume_role_policy.json
  name               = "eks-cluster-autoscaler"
}

resource "aws_iam_policy" "eks_cluster_autoscaler" {
  name = "eks-cluster-autoscaler"

  policy = jsonencode({
    Statement = [{
      Action = [
                "autoscaling:DescribeAutoScalingGroups",
                "autoscaling:DescribeAutoScalingInstances",
                "autoscaling:DescribeLaunchConfigurations",
                "autoscaling:DescribeTags",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:TerminateInstanceInAutoScalingGroup",
                "ec2:DescribeLaunchTemplateVersions"
            ]
      Effect   = "Allow"
      Resource = "*"
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_autoscaler_attach" {
  role       = aws_iam_role.eks_cluster_autoscaler.name
  policy_arn = aws_iam_policy.eks_cluster_autoscaler.arn
}

output "eks_cluster_autoscaler_arn" {
  value = aws_iam_role.eks_cluster_autoscaler.arn
}
```

# Apply the terraform again
```
terraform apply --auto-approve
```

# Let's create autoscaler configuration
You can find the source code here [Cluster Autoscaler](https://github.com/antonputra/tutorials/blob/main/lessons/102/k8s/cluster-autoscaler.yaml).

# Create a file and name it iam-autoscaler.yaml

# Let's apply the iam-autoscaler.yaml file
```
kubectl apply -f iam-autoscaler.yaml
```

# You can verify that the autoscaler pod is up and running with the following command.
```
kubectl get pods -n kube-system
```

# It's a good practice to check logs for any errors. 
```
kubectl logs -l app=cluster-autoscaler -n kube-system -f
```

# EKS cluster auto scaling demo
```
    Verify that AG (aws autoscaling group) has required tags:
        k8s.io/cluster-autoscaler/<cluster-name> : owned
        k8s.io/cluster-autoscaler/enabled : TRUE
```

# Install watch command in vscode
```
npm install -g watch
```

[ ]  Split the terminal screen. In the first window run:

```
kubectl get pods --watch
```

# In the second window run:
```
kubectl get nodes --watch
```

# In the third window: Now, to trigger autoscaling, increase replica for nginx deployment from 1 to 5.
```
kubectl apply -f deployment.yaml
```