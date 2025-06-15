name: Deploy to AWS

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout du code
      uses: actions/checkout@v4

    - name: Installer Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: latest

    - name: Initialiser Terraform
      run: terraform init
      working-directory: ./preProd-terraform  # Assure-toi d'ajuster ce chemin

    - name: Plan Terraform
      run: terraform plan
      working-directory: ./terraform

    - name: Appliquer Terraform
      run: terraform apply -auto-approve
      working-directory: ./terraform

    - name: Récupérer l'IP de l'instance
      id: get_ip
      run: echo "INSTANCE_IP=$(terraform output -raw instance_public_ip)" >> $GITHUB_ENV
      working-directory: ./terraform

    - name: Ajouter la clé SSH
      run: |
        echo "${{ secrets.SSH_PRIVATE_KEY }}" > ssh_key.pem
        chmod 600 ssh_key.pem

    - name: Installer Ansible
      run: sudo apt update && sudo apt install -y ansible

    - name: Configurer Ansible Inventory
      run: |
        echo "[servers]" > inventory.ini
        echo "${{ env.INSTANCE_IP }} ansible_user=ubuntu ansible_ssh_private_key_file=ssh_key.pem" >> inventory.ini

    - name: Exécuter le playbook Ansible
      run: ansible-playbook -i inventory.ini ansible/playbook.yml


#Configuration des Secrets GitHub

#Ajoute ces secrets dans les paramètres de ton repo GitHub → Settings → Secrets → Actions :
#AWS_ACCESS_KEY_ID
#AWS_SECRET_ACCESS_KEY
#SSH_PRIVATE_KEY (Ta clé privée pour accéder à l'instance)

# Explication du Workflow

#Clone le repo
#Installe Terraform et applique la config
#Récupère l'IP de l'instance AWS créée
#Ajoute la clé SSH pour la connexion
#Installe Ansible et exécute le playbook sur l'instance