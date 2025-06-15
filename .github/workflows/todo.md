 Error: importing EC2 Key Pair (vockey): operation error EC2: ImportKeyPair, https response error StatusCode: 400, RequestID: 7c9303b6-420f-433b-8be3-17e94a9dedcf, api error InvalidKeyPair.Duplicate: The keypair already exists
│ 
│   with aws_key_pair.vockey,
│   on main.tf line 46, in resource "aws_key_pair" "vockey":
│   46: resource "aws_key_pair" "vockey" {
│ 
╵
╷
│ Error: creating Security Group (admin-ssh): operation error EC2: CreateSecurityGroup, https response error StatusCode: 400, RequestID: bffc6b30-4918-4ae1-a049-9ed5db0ca9b8, api error InvalidGroup.Duplicate: The security group 'admin-ssh' already exists for VPC 'vpc-09c4b38653df63f28'
│ 
│   with aws_security_group.admin_ssh,
│   on main.tf line 85, in resource "aws_securit

✅ Pourquoi cette erreur survient ?
La clé SSH vockey et le Security Group admin-ssh existent déjà sur AWS.
Terraform essaie de les recréer, mais AWS refuse (erreur InvalidKeyPair.Duplicate et InvalidGroup.Duplicate).
Terraform ne sait pas que ces ressources existent déjà, il faut donc les importer dans son état (terraform state).


✅ Solution définitive pour ton workflow GitHub Actions
1️⃣ Modifier Terraform pour éviter le conflit
Ajoute ces directives lifecycle dans ton main.tf :

hcl
Copier
Modifier
resource "aws_key_pair" "vockey" {
  key_name   = "vockey"
  public_key = tls_private_key.vockey.public_key_openssh

  lifecycle {
    ignore_changes = [key_name]  # Ignore si la clé existe déjà
  }
}

resource "aws_security_group" "admin_ssh" {
  name   = "admin-ssh"
  vpc_id = "vpc-09c4b38653df63f28"

  lifecycle {
    ignore_changes = [name]  # Ignore si le groupe existe déjà
  }

  tags = {
    Name = "admin-ssh"
  }
}
2️⃣ Mettre à jour ton workflow GitHub Actions
Ajoute ces étapes avant terraform apply dans ton fichier .github/workflows/deploy.yml :

yaml
Copier
Modifier
- name: Import existing AWS key pair
  run: terraform import aws_key_pair.vockey vockey || echo "Key Pair already imported"

- name: Import existing Security Group
  run: terraform import aws_security_group.admin_ssh sg-xxxxxxxxxxxxxxxxx || echo "Security Group already imported"
➡ Remplace sg-xxxxxxxxxxxxxxxxx par l'ID réel de ton groupe de sécurité (terraform output sg_id peut t’aider).

3️⃣ Vérifier Terraform avant application
Ajoute cette étape pour vérifier si Terraform veut recréer les ressources :

yaml
Copier
Modifier
- name: Terraform Plan
  run: terraform plan -no-color
Si le plan montre que vockey ou admin-ssh va être recréé, alors il manque l’import.

4️⃣ Forcer Terraform à ignorer l’erreur sur les ressources existantes
Ajoute une commande pour réparer l’état Terraform si nécessaire :

yaml
Copier
Modifier
- name: Remove duplicated resources from state
  run: |
    terraform state rm aws_key_pair.vockey || true
    terraform state rm aws_security_group.admin_ssh || true
    terraform import aws_key_pair.vockey vockey || echo "Key Pair already exists"
    terraform import aws_security_group.admin_ssh sg-xxxxxxxxxxxxxxxxx || echo "Security Group already exists"
👉 Ça force Terraform à oublier ces ressources et à les réimporter proprement.

✅ Conclusion
Avec ces changements, Terraform : ✔ Importe la clé SSH et le groupe de sécurité s'ils existent déjà
✔ Ignore la recréation des ressources pour éviter les erreurs
✔ Continue le déploiement même si la clé ou le groupe existent