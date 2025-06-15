#  Créer un rôle IAM et un service account Kubernetes
#  AWS Load Balancer Controller

# Créer le rôle IAM pour le contrôleur
resource "aws_iam_role" "aws_lb_controller_role" {
  name = "aws-lb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRoleWithWebIdentity"
        Effect    = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/oidc.eks.${var.region}.amazonaws.com/id/${module.eks.cluster_id}"
        }
      },
    ]
  })

  tags = {
    Name = "aws-lb-controller-role"
  }
}


# Créer les politiques IAM nécessaires pour ce rôle
resource "aws_iam_policy" "aws_lb_controller_policy" {
  name        = "aws-lb-controller-policy"
  description = "Policy for AWS Load Balancer Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ec2:DescribeLoadBalancers",
          "ec2:DescribeLoadBalancerAttributes",
          "ec2:CreateLoadBalancer",
          "ec2:DeleteLoadBalancer",
          "ec2:CreateTargetGroup",
          "ec2:DeleteTargetGroup",
          "ec2:ModifyTargetGroup",
          "ec2:DescribeTargetGroups",
          "ec2:DescribeListeners",
          "ec2:CreateListener",
          "ec2:DeleteListener",
          "ec2:ModifyListener",
          "ec2:DescribeInstanceHealth",
          "ec2:DescribeSecurityGroups",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup"
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "aws_lb_controller_attach_policy" {
  policy_arn = aws_iam_policy.aws_lb_controller_policy.arn
  role       = aws_iam_role.aws_lb_controller_role.name
}


# Créer le service account Kubernetes et lier le rôle IAM
# Le rôle IAM doit être associé à un Service Account dans Kubernetes.

resource "kubernetes_service_account" "aws_lb_controller_sa" {
  metadata {
    name      = "aws-lb-controller"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "aws_lb_controller_binding" {
  metadata {
    name = "aws-lb-controller"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.aws_lb_controller_sa.metadata[0].name
    namespace = kubernetes_service_account.aws_lb_controller_sa.metadata[0].namespace
  }

  role_ref {
    kind = "ClusterRole"
    name = "cluster-admin"
  }
}

# Installer le AWS Load Balancer Controller via Helm
# utiliser Terraform pour déployer le AWS Load Balancer Controller en utilisant Helm.utiliser Terraform pour déployer le AWS Load Balancer Controller en utilisant Helm.

resource "helm_release" "aws_lb_controller" {
  name       = "aws-lb-controller"
  repository = "https://kubernetes-sigs.github.io/aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  values = [
    yamlencode({
      clusterName = var.cluster_name
      serviceAccount = {
        create = false
        name   = kubernetes_service_account.aws_lb_controller_sa.metadata[0].name
      }
      region = var.region
      vpcId  = var.vpc_id
    })
  ]
}
