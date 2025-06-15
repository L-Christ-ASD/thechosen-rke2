#!/bin/bash

# Supprimer le rôle de l'instance profile avant de supprimer l'instance profile
echo "Détacher le rôle EC2LoadBalancerRole du profil d'instance EC2LoadBalancerInstanceProfile..."
aws iam remove-role-from-instance-profile --instance-profile-name EC2LoadBalancerInstanceProfile --role-name EC2LoadBalancerRole

# Supprimer les rôles et les profils d'instance
echo "Suppression du profil d'instance EC2LoadBalancerInstanceProfile..."
aws iam delete-instance-profile --instance-profile-name EC2LoadBalancerInstanceProfile

echo "Suppression du rôle IAM EC2LoadBalancerRole..."
aws iam delete-role --role-name EC2LoadBalancerRole

# Vérifier si la politique EC2ELBAccessPolicy existe et la supprimer si nécessaire
echo "Vérification de la politique EC2ELBAccessPolicy..."
POLICY_EXISTS=$(aws iam list-policies --query "Policies[?PolicyName=='EC2ELBAccessPolicy'].PolicyName" --output text)

if [ "$POLICY_EXISTS" == "EC2ELBAccessPolicy" ]; then
  echo "Suppression de la politique EC2ELBAccessPolicy..."
  aws iam delete-policy --policy-arn arn:aws:iam::aws:policy/EC2ELBAccessPolicy
else
  echo "La politique EC2ELBAccessPolicy n'a pas été trouvée."
fi

echo "Nettoyage terminé."


# Applique Terraform
echo "Application du plan Terraform..."

