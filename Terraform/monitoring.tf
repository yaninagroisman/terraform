# Monitoring host: Prometheus (+ node-exporter now; Grafana and Alertmanager later) on an EC2
# instance in a private subnet. Config files live in ./monitoring, are uploaded to S3 by Terraform
# and pulled by the instance every 5 minutes, so a config change is just `terraform apply`.
#
# How Prometheus sees the application: with the VPC CNI every pod has a VPC IP. Prometheus asks the
# EKS API for the pods (kubernetes_sd_configs, read-only RBAC) and scrapes them directly on :5000.

locals {
  monitoring_name = "${var.project_name}-monitoring"
}

# Amazon Linux 2023: SSM agent and AWS CLI preinstalled
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ---------- Config bucket ----------

resource "aws_s3_bucket" "monitoring" {
  bucket        = "${local.monitoring_name}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true # only generated config inside; must not block terraform destroy
}

resource "aws_s3_bucket_public_access_block" "monitoring" {
  bucket                  = aws_s3_bucket.monitoring.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "monitoring" {
  for_each = fileset("${path.module}/monitoring", "**")

  bucket = aws_s3_bucket.monitoring.id
  key    = each.value
  source = "${path.module}/monitoring/${each.value}"
  etag   = filemd5("${path.module}/monitoring/${each.value}")
}

# ---------- Network ----------

resource "aws_security_group" "monitoring" {
  name        = "${local.monitoring_name}-sg"
  description = "Monitoring host (Prometheus)"
  vpc_id      = module.network.vpc_id

  tags = {
    Name = "${local.monitoring_name}-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "monitoring_out" {
  security_group_id = aws_security_group.monitoring.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Prometheus -> application pods (pod IPs use the node security group)
resource "aws_vpc_security_group_ingress_rule" "eks_nodes_from_monitoring" {
  security_group_id            = module.eks.node_security_group_id
  referenced_security_group_id = aws_security_group.monitoring.id
  ip_protocol                  = "tcp"
  from_port                    = 5000
  to_port                      = 5000
  description                  = "Prometheus scrapes weather pods"
}

# Prometheus -> EKS API (private endpoint) for pod discovery
resource "aws_vpc_security_group_ingress_rule" "eks_api_from_monitoring" {
  security_group_id            = module.eks.cluster_security_group_id
  referenced_security_group_id = aws_security_group.monitoring.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Prometheus Kubernetes service discovery"
}

# ---------- IAM ----------

data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name               = local.monitoring_name
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
}

resource "aws_iam_role_policy_attachment" "monitoring_ssm" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "monitoring" {
  name = "monitoring-host"
  role = aws_iam_role.monitoring.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadConfig"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.monitoring.arn
      },
      {
        Sid      = "ReadConfigObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.monitoring.arn}/*"
      },
      {
        Sid      = "DescribeCluster"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${local.cluster_name}"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "monitoring" {
  name = local.monitoring_name
  role = aws_iam_role.monitoring.name
}

# ---------- Instance ----------

resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.small"
  subnet_id              = module.network.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  iam_instance_profile   = aws_iam_instance_profile.monitoring.name

  user_data = templatefile("${path.module}/monitoring-user-data.sh.tftpl", {
    bucket       = aws_s3_bucket.monitoring.id
    cluster_name = local.cluster_name
    aws_region   = var.aws_region
  })
  # Nothing important lives on this host yet, so a changed boot script simply rebuilds it
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name      = local.monitoring_name
    Project   = var.project_name
    Role      = "monitoring"
    ManagedBy = "Terraform"
  }

  lifecycle {
    ignore_changes = [ami] # a new Amazon Linux release must not replace the host on every apply
  }

  depends_on = [aws_s3_object.monitoring]
}

resource "aws_route53_record" "monitoring_internal" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "monitoring.internal.${var.domain_name}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.monitoring.private_ip]
}

# ---------- Read-only access to the cluster for service discovery ----------

resource "aws_eks_access_entry" "monitoring" {
  cluster_name      = module.eks.cluster_name
  principal_arn     = aws_iam_role.monitoring.arn
  type              = "STANDARD"
  kubernetes_groups = ["prometheus-readers"]
}

resource "kubernetes_cluster_role_v1" "prometheus_readers" {
  metadata {
    name = "prometheus-readers"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "endpoints", "services", "nodes"]
    verbs      = ["get", "list", "watch"]
  }

  depends_on = [module.eks]
}

resource "kubernetes_cluster_role_binding_v1" "prometheus_readers" {
  metadata {
    name = "prometheus-readers"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.prometheus_readers.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "prometheus-readers"
    api_group = "rbac.authorization.k8s.io"
  }
}

output "monitoring_instance_id" {
  value = aws_instance.monitoring.id
}

output "prometheus_tunnel_command" {
  description = "Opens Prometheus on http://localhost:9090"
  value       = "aws ssm start-session --region ${var.aws_region} --target ${aws_instance.monitoring.id} --document-name AWS-StartPortForwardingSession --parameters portNumber=9090,localPortNumber=9090"
}
