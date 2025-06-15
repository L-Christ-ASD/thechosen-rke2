provider "aws" {
  region = "us-east-1"
}

# Variable Innstance 
#=====================================
variable "ec2_type_preprod" {
  description = "le type d'instance souhaité"
  type        = string
  default     = "t3a.2xlarge"
}

variable "counterInstance_preprod" {
  description = "Nombre d'instance a creer"
  #type = string
  default = 3
}

variable "counterInstance_preprod_workers" {
  description = "Nombre d'instance a creer"
  #type = string
  default = 2
}

# Variable autorisation d'ip (Innstances)
variable "admin-ips" {
  description = "les ip's des admins"
  default     = ["192.168.1.0", "77.207.199.0"]
}

variable "mon_ip" {
  description = "Les adresses acceptéés"
  type        = string
  default     = "176.172.132.0"
}


#                 Cluster rke2 instances
# ======================================
#                     3 Masters
#=======================================
resource "aws_instance" "masters" {

  count                  = var.counterInstance_preprod # creation multiple des instances
  ami                    = "ami-04b4f1a9cf54c11d0"
  instance_type          = var.ec2_type_preprod
  key_name               = aws_key_pair.vockeyprod.key_name
  subnet_id              = "subnet-07ef8d731542349d5" #  sous-réseau appartenant au vpc-09c4b38653df63f28
  vpc_security_group_ids = [aws_security_group.admin_ssh_production.id]

  source_dest_check = false

  iam_instance_profile = aws_iam_instance_profile.ec2_lb_instance_profile.name

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_security_group.admin_ssh_production, aws_key_pair.vockeyprod] # Assure l'ordre de création

  tags = {
    Name                                      = "master${count.index + 1}"
    "kubernetes.io/cluster/apotheose-cluster" = "owned" # Ce tag est indispensable pour ELB / CCM"
    "topology.kubernetes.io/region"           = "us-east-1"
    "topology.kubernetes.io/zone"             = "us-east-1f"
    "k8s.io/role/node"                        = "master" #${count.index + 1}"

  }
}


#                  2 workers
#======================================
resource "aws_instance" "workers" {

  count                  = var.counterInstance_preprod_workers # creation multiple des instances
  ami                    = "ami-04b4f1a9cf54c11d0"
  instance_type          = var.ec2_type_preprod #"t2.xlarge" #
  key_name               = aws_key_pair.vockeyprod.key_name
  subnet_id              = "subnet-07ef8d731542349d5" #  sous-réseau vpc-09c4b38653df63f28
  vpc_security_group_ids = [aws_security_group.admin_ssh_production.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_lb_instance_profile.name

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_security_group.admin_ssh_production, aws_key_pair.vockeyprod] # Assure l'ordre de création

  tags = {
    Name                                      = "worker${count.index + 1}"
    "kubernetes.io/cluster/apotheose-cluster" = "owned" # tag obligatoire pour CCM
    "topology.kubernetes.io/region"           = "us-east-1"
    "topology.kubernetes.io/zone"             = "us-east-1f"
    "k8s.io/role/node"                        = "worker" #${count.index}"
  }

}


#       tls_private_key → Génère une clé privée
#===================================================
resource "tls_private_key" "vockeyprod" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# aws_key_pair → Crée la clé publique sur AWS.
resource "aws_key_pair" "vockeyprod" {
  key_name   = "vockeyprod"
  public_key = tls_private_key.vockeyprod.public_key_openssh

  lifecycle {
    ignore_changes = [key_name] # Ignore si la clé existe déjà
  }
}

# local_file → Stocke la clé privée (vockey.pem) localement.
resource "local_file" "vockeyprod_pem" {
  filename        = "${path.module}/vockeyprod.pem"
  content         = tls_private_key.vockeyprod.private_key_pem
  file_permission = "0600"
}


#                 Outputs
#=============================================
output "instance_info_prod_master" {
  value = {
    master_prod_public_ip = aws_instance.masters[*].public_ip
  }
}

# output "network_interface_master1_eni" {
#   value = {
#     master_prod_public_ip = aws_instance.masters[0].interface
#   }
# }

output "instance_info_prod_worker" {
  value = {
    worker_prod_public_ip = aws_instance.workers[*].public_ip
  }
}


output "ssh_key_name" {
  value = aws_key_pair.vockeyprod.key_name
}

output "ssh_private_key_filename" {
  value = local_file.vockeyprod_pem.filename
}




#____________________exportation d'IP ________________________
#=============================================================

#exportation d'IP masters vers ansible/inventory
resource "null_resource" "generate_ansible_inventory-masters" {
  depends_on = [aws_instance.masters]

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ../../ansible_production
      echo "[masters]" >> ../../ansible_production/inventory

      # Ajouter master1 avec son IP spécifique
      echo "master1 ansible_host=${aws_instance.masters[0].public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=./vockeyprod.pem ansible_ssh_extra_args='-o StrictHostKeyChecking=no'" >> ../../ansible_production/inventory

      # Ajouter les autres masters avec un nom explicite
      ${join("\n", formatlist("echo \"master%d ansible_host=%s ansible_user=ubuntu ansible_ssh_private_key_file=./vockeyprod.pem ansible_ssh_extra_args='-o StrictHostKeyChecking=no'\" >> ../../ansible_production/inventory", range(2, length(aws_instance.masters) + 1), slice(aws_instance.masters[*].public_ip, 1, length(aws_instance.masters))))}
    EOT
  }
}

# exportation d'IP workers vers ansible/inventory
resource "null_resource" "generate_ansible_inventory-workers" {
  depends_on = [aws_instance.workers]

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ../../ansible_production
      echo "[workers]" >> ../../ansible_production/inventory

      # Ajouter les workers
      ${join("\n", formatlist("echo \"worker%d ansible_host=%s ansible_user=ubuntu ansible_ssh_private_key_file=./vockeyprod.pem ansible_ssh_extra_args='-o StrictHostKeyChecking=no'\" >> ../../ansible_production/inventory", range(1, length(aws_instance.workers) + 1), aws_instance.workers[*].public_ip))}
    EOT
  }
}
#-----------------------------------------
#exportation de l'id de master1 vers /nstance-id pour kube-vip
resource "null_resource" "generate-instance-id-master1" {
  depends_on = [aws_instance.masters]

  provisioner "local-exec" {
    command = <<EOT
   
      echo "${aws_instance.masters[0].id}" > ../../instance-id

    EOT
  }
}



#_____________Creation de security group___________
# =================================================.

# Création du groupe de sécurité s'il n'existe pas déjà
resource "aws_security_group" "admin_ssh_production" {
  name   = "admin_ssh_production"
  vpc_id = "vpc-09c4b38653df63f28" # The chosen vpc

  lifecycle {
    ignore_changes = [name] # Ignore si le groupe existe déjà
  }

  tags = {
    Name = "admin_ssh_production"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_in_myip" {
  security_group_id = aws_security_group.admin_ssh_production.id
  cidr_ipv4         = "${var.mon_ip}/24"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


resource "aws_vpc_security_group_ingress_rule" "allow_ssh_in" {
  for_each          = toset(var.admin-ips)
  security_group_id = aws_security_group.admin_ssh_production.id
  cidr_ipv4         = "${each.value}/24"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_ssh_out" {
  security_group_id = aws_security_group.admin_ssh_production.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_in" {
  security_group_id = aws_security_group.admin_ssh_production.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_in" {
  security_group_id = aws_security_group.admin_ssh_production.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}


#==================================== K8S PORTS ================================================
# temporairement pour le worker k8s
resource "aws_vpc_security_group_ingress_rule" "allow_port_9345" {
  security_group_id = aws_security_group.admin_ssh_production.id
  cidr_ipv4         = "172.31.0.0/16"
  from_port         = 9345
  ip_protocol       = "tcp"
  to_port           = 9345
}
# temporairement pour le worker k8s
resource "aws_vpc_security_group_ingress_rule" "allow_port_6443" {
  security_group_id = aws_security_group.admin_ssh_production.id
  cidr_ipv4         = "172.31.0.0/16"
  from_port         = 6443
  ip_protocol       = "tcp"
  to_port           = 6443
}
# temporairement pour le worker k8s
resource "aws_vpc_security_group_ingress_rule" "allow_port_UDP" {
  security_group_id = aws_security_group.admin_ssh_production.id
  cidr_ipv4         = "172.31.0.0/16"
  from_port         = 8472
  ip_protocol       = "udp"
  to_port           = 8472
}
# temporairement pour le worker k8s
resource "aws_vpc_security_group_ingress_rule" "allow_port_10250" {
  security_group_id = aws_security_group.admin_ssh_production.id
  cidr_ipv4         = "172.31.0.0/16"
  from_port         = 10250
  ip_protocol       = "tcp"
  to_port           = 10250
}

# temporairement pour le worker k8s
resource "aws_vpc_security_group_ingress_rule" "allow_port_8080" {
  security_group_id = aws_security_group.admin_ssh_production.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
}


#=======================================================================
# permettre le trafic interne entre les ressources qui appartiennent au groupe admin_ssh_production
resource "aws_security_group_rule" "allow_tcp_2379" {
  type                     = "ingress"
  from_port                = 2379
  to_port                  = 2379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.admin_ssh_production.id # Groupe de sécurité cible
  source_security_group_id = aws_security_group.admin_ssh_production.id # Groupe de sécurité source
}

resource "aws_security_group_rule" "allow_tcp_2380" {
  type                     = "ingress"
  from_port                = 2380
  to_port                  = 2380
  protocol                 = "tcp"
  security_group_id        = aws_security_group.admin_ssh_production.id # Groupe de sécurité cible
  source_security_group_id = aws_security_group.admin_ssh_production.id # Groupe de sécurité source
}

#==============================================================
#                       KUBE-VIP
#==============================================================
#               temporairement pour KUBE-VIP
#               =============================
# Réservé la VIP dans le subnet (pour le routage aws)
# resource "aws_network_interface" "vip_on_master1" {
#   private_ips     = ["172.31.75.164"]
#   subnet_id       = "subnet-07ef8d731542349d5"
#   description     = "Reserved VIP for Kube-VIP"
#   security_groups = [aws_security_group.admin_ssh_production.id]
# }

# L'IP est déclarée à AWS, mais non fixée à un seul master 
# → kube-vip GERE dynamiquement 
# (failover entre masters).


# Configurer sourceDestCheck = false sur tous les masters
# Permettre la prise de l’IP secondaire sur un autre nœud 
# (failover via ARP spoofing local)

#-------------------------------------------------------
# resource "aws_vpc_security_group_ingress_rule" "tcp_kube_vip" {
#   security_group_id = aws_security_group.admin_ssh_production.id
#   cidr_ipv4         = "172.31.0.0/20"
#   from_port         = 9345
#   ip_protocol       = "tcp"
#   to_port           = 9345
# }

# # ping KUBE-VIP
resource "aws_vpc_security_group_ingress_rule" "allow_port_ping_kube_vip" {
  security_group_id = aws_security_group.admin_ssh_production.id
  cidr_ipv4         = "172.31.0.0/16"
  from_port         = -1
  ip_protocol       = "icmp"
  to_port           = -1
}

# # ping ALL
# resource "aws_vpc_security_group_ingress_rule" "allow_all_ping" {
#   security_group_id = aws_security_group.admin_ssh_production.id
#   cidr_ipv4         = "0.0.0.0/0"
#   from_port         = 8
#   ip_protocol       = "icmp"
#   to_port           = -1
# }
# FIN DE KUBE-VIP
#=====================


#=============================================================================================
# ===============Pour la gestion du cluster via ma machine locale (bastion)================
resource "aws_vpc_security_group_ingress_rule" "allow_6443" {
  security_group_id = aws_security_group.admin_ssh_production.id
  cidr_ipv4         = "${var.mon_ip}/24"
  from_port         = 6443
  ip_protocol       = "tcp"
  to_port           = 6443
}

# temporairement pour openVPN
resource "aws_vpc_security_group_ingress_rule" "allow_port_1194" {
  security_group_id = aws_security_group.admin_ssh_production.id
  cidr_ipv4         = "${var.mon_ip}/24"
  from_port         = 1194
  ip_protocol       = "udp"
  to_port           = 1194
}


#=============================================================================================
#========================== rôle IAM pour elb==================
resource "aws_iam_role" "ec2_load_balancer_role" {
  name = "EC2LoadBalancerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "ec2_elb_custom_policy" {
  name        = "EC2ELBAccessPolicy"
  description = "Custom policy to manage ELB and related resources"

  policy = file("${path.module}/ec2_elb_policy.json")
}


resource "aws_iam_role_policy_attachment" "attach_custom_elb_policy" {
  role       = aws_iam_role.ec2_load_balancer_role.name
  policy_arn = aws_iam_policy.ec2_elb_custom_policy.arn
}


resource "aws_iam_instance_profile" "ec2_lb_instance_profile" {
  name = "EC2LoadBalancerInstanceProfile"
  role = aws_iam_role.ec2_load_balancer_role.name

}


#======================= A REVOIR: creer un sg juste pour traefik =============================================
# groupe de securité dans traefik.yml
output "ID_admin_ssh_production" {
  value = aws_security_group.admin_ssh_production.id
}

# exportation de sg
resource "null_resource" "update_traefik_values_yaml_sg" {
  depends_on = [aws_instance.masters]

  provisioner "local-exec" {
    command = <<EOT

      echo "sg: ${aws_security_group.admin_ssh_production.id}" >> ${path.module}/../../helm_thechosen/traefik/values.yaml
 
    EOT
  }
}


#================= TAGS SUBNET POUR KUBERNETES =====================
resource "aws_ec2_tag" "subnet_tag_elb" {
  resource_id = "subnet-07ef8d731542349d5" # subnet AWS ec2
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "subnet_tag_cluster" {
  resource_id = "subnet-07ef8d731542349d5"
  key         = "kubernetes.io/cluster/apotheose"
  value       = "owned"
}




#===================================================
# Définir un aws_ebs_volume pour chaque instance
# Attacher ce volume à l'instance EC2
#===================================================

# Créer un volume EBS pour chaque instance EC2 (workers), 
#comme disque de stockage pour /var/lib/containerd (rke2, pour eviter les pods evicted)

locals {
  #all_instances = concat(aws_instance.workers[*])
  all_instances = concat(aws_instance.masters[*], aws_instance.workers[*])
}

resource "aws_ebs_volume" "apotheose_volume" {
  count             = length(local.all_instances)
  availability_zone = local.all_instances[count.index].availability_zone
  size              = 65
  type              = "gp2"
}

resource "aws_volume_attachment" "apotheose_volume_attachment" {
  count       = length(local.all_instances)
  device_name = "/dev/sdf"
  instance_id = local.all_instances[count.index].id
  volume_id   = aws_ebs_volume.apotheose_volume[count.index].id
}

#-----------------------------------------------------------------
# EBS pour Cstor des workers
locals {
  all_instances_workers = concat(aws_instance.workers[*])
  device_letters        = ["g", "h"]
  #all_instances = concat(aws_instance.masters[*], aws_instance.workers[*])
  #device_letters = ["g", "h", "i", "j", "k"] # "l", "m", "n"]
}

resource "aws_ebs_volume" "apotheose_volume_cstor" {
  count             = length(local.all_instances_workers)
  availability_zone = local.all_instances_workers[count.index].availability_zone
  size              = 60
  type              = "gp2"
}

resource "aws_volume_attachment" "apotheose_volume_cstor_attachment" {
  count       = length(local.all_instances_workers)
  device_name = "/dev/sd${local.device_letters[count.index]}"
  instance_id = local.all_instances_workers[count.index].id
  volume_id   = aws_ebs_volume.apotheose_volume_cstor[count.index].id
}


#================================ EIP =============================
#========================== custum ================================
# Créer une EIP 
resource "aws_eip" "traefik_eip" {
  domain = "vpc"
  tags = {
    Name = "traefik-lb-eip"
  }
}

output "eip_allocation_id" {
  value       = aws_eip.traefik_eip.id
  description = "Elastic IP Allocation ID"
}

# exportation d eip_allocation_id
resource "null_resource" "update_values_yaml" {
  triggers = {
    eip_allocation_id = aws_eip.traefik_eip.id # Déclenche quand l'ID de l'EIP change
  }

  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ../../ansible_production

      echo "eipAllocationId: ${aws_eip.traefik_eip.id}" >> ${path.module}/../../helm_thechosen/traefik/values.yaml

    EOT
  }
}



#----------------------------------------------------------------------------
#----------------------------------------------------------------------------
#----------------------------------------------------------------------------
# try traefik2 dynamic config
#===============

variable "subnet_id" {
  default = "subnet-07ef8d731542349d5"
}

locals {
  values_dynamic_yaml = yamlencode({
    service = {
      annotations = {
        "service.beta.kubernetes.io/aws-load-balancer-type"            = "nlb"
        "service.beta.kubernetes.io/aws-load-balancer-subnets"         = tostring(var.subnet_id)
        "service.beta.kubernetes.io/aws-load-balancer-security-groups" = tostring(aws_security_group.admin_ssh_production.id)
        "service.beta.kubernetes.io/aws-load-balancer-eip-allocations" = tostring(aws_eip.traefik_eip.id)
      }
    }
  })
}


resource "local_file" "values_dynamic" {
  filename = "${path.module}/../../traefik2/values_dynamic.yaml"
  content  = local.values_dynamic_yaml
}












#______COMMANDE AWS
#======================
#SIGNATURE EXPIRED:
#cmd:
# sudo timedatectl set-ntp true
# sudo timedatectl

#lister toutes les EIPs (et leurs AllocationId):
# aws ec2 describe-addresses --query "Addresses[*].{PublicIp:PublicIp, AllocationId:AllocationId, Associated:AssociationId != null}" --output table
#ou:
# aws ec2 describe-addresses
#ou:
# aws ec2 describe-addresses --allocation-ids eipalloc-xxxxxxxxxxxxxxxxx

# DELETE:
# Étape 1 : Détacher le rôle du profil
# aws iam remove-role-from-instance-profile \
#   --instance-profile-name EC2LoadBalancerInstanceProfile \
#   --role-name ec2-load-balancer-role

# # Étape 2 : Supprimer le profil IAM
# aws iam delete-instance-profile --instance-profile-name EC2LoadBalancerInstanceProfile


# aws ec2 describe-internet-gateways \
#   --filters "Name=attachment.vpc-id,Values=vpc-09c4b38653df63f28" \
#   --query "InternetGateways[].InternetGatewayId" \
#   --output text

# resource "aws_route" "public_subnet_internet_access" {
#   route_table_id         = "rtb-xxxxxxxx" # Remplace par l’ID de la route table associée au subnet
#   destination_cidr_block = "0.0.0.0/0"
#   gateway_id             = "igw-0d453ef874a801185" 
# }

# aws ec2 describe-route-tables \
#   --filters "Name=association.subnet-id,Values=subnet-07ef8d731542349d5" \
#   --query "RouteTables[].RouteTableId" \
#   --output text





#========================================================
#========================== temporairement pour NodePort ==================

#resource "aws_vpc_security_group_ingress_rule" "allow_80_30080" {
#  security_group_id = aws_security_group.admin_ssh_production.id
#  cidr_ipv4         = "0.0.0.0/0"
#  from_port         = 30080
#  ip_protocol       = "tcp"
#  to_port           = 30080
#}
#
#resource "aws_vpc_security_group_ingress_rule" "allow_https_30443" {
#  security_group_id = aws_security_group.admin_ssh_production.id
#  cidr_ipv4         = "0.0.0.0/0"
#  from_port         = 30443
#  ip_protocol       = "tcp"
#  to_port           = 30443
#}
#
#resource "aws_vpc_security_group_ingress_rule" "dashboard_30808" {
#  security_group_id = aws_security_group.admin_ssh_production.id
#  cidr_ipv4         = "0.0.0.0/0"
#  from_port         = 30808
#  ip_protocol       = "tcp"
#  to_port           = 30808
#}
#
##========================== Rôle IAM (aws_iam_role) pour la créaation automatique de ELB =================
#
##resource "aws_iam_instance_profile" "ec2_instance_profile" {
##  name = "ec2-instance-profile"
#  role = aws_iam_role.ec2_role.name
#}
#
#
#resource "aws_iam_role" "ec2_role" {
#  name = "ec2-load-balancer-role"
#  assume_role_policy = jsonencode({
#    Version = "2012-10-17"
#    Statement = [
#      {
#        Effect = "Allow"
#        Principal = {
#          Service = "ec2.amazonaws.com"
#        }
#        Action = "sts:AssumeRole"
#      }
#    ]
#  })
#}
#
#resource "aws_iam_policy" "ec2_load_balancer_policy" {
#  name        = "EC2LoadBalancerPolicy"
#  description = "Policy for EC2 to manage Elastic Load Balancers and Security Groups"
#  policy = jsonencode({
#    Version = "2012-10-17"
#    Statement = [
#      {
#        Effect   = "Allow"
#        Action   = [
#          "elasticloadbalancing:*",
#          "ec2:Describe*",
#          "ec2:CreateSecurityGroup",
#          "ec2:AuthorizeSecurityGroupIngress"
#        ]
#        Resource = "*"
#      }
#    ]
#  })
#}
#
#resource "aws_iam_role_policy_attachment" "attach_policy" {
#  role       = aws_iam_role.ec2_role.name
#  policy_arn = aws_iam_policy.ec2_load_balancer_policy.arn
#}



