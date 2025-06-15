![CI/CD The Chosen](https://github.com/L-Christ-ASD/projet_final/actions/workflows/aws_push.yml/badge.svg)


# Solution cms (WordPress) avec une architecture trois tiers
Déploiement avec kubernetes rke2

## 1. Introduction
Ce document présente un projet automatisé du déploiement (mise en production/staging) d’une stack complète offrant une solution cms (WordPress) avec une architecture trois tiers (front, back,bdd) et une solution de supervision des services, via kubernetes k8s. Le cluster est constitué de cinq nœuds dont trois masters et deux workers, configurés automatiquement sur les instances ec2 avec le provider aws via ansible.  Afin de favoriser la flexibilité et la migration de ce projet, le cluster est configuré en mode **self-maged** en **haute disponibilité** et donc, n’est pas attaché à un provider donné. Les technologies utilisées dans la stack et les configurations peuvent-être remplacées ou modifiées pour adapter le projet selon le besoin.


## 2. Prérequis:  
Pour faciliter une bonne prise en main de ce projet, il est recommandé d’avoir certaines connaissances et notions (avancées) sur kubernetes, et sur les outils annoncés dans les technologies utilisées. 


* *Matériel*: Terminal, éditeur de texte et navigateur web.


## 3. Technologies utilisées:  
**Ansible** : Configurations des serveurs distant
**Terraform**: Créations automatique des ressources aws (+ccm)
**Github actions** (workflows): CI/CD
**Kubernetes**: Cluster rke2 de cinq noeuds
**Kubectl**: pour la gestion du cluster à distance
**kube-vip**: Ip virtuelle flottante pour la HA du cluster
**OpenEbs**(C-stor): gestion automatique des volumes en HA
**Helm**: Déploiement des applications (services)
**ArgoCD**: pour la livraison continue
**Grafana/Prometheus**: Supervision de l’infrastructure (monitoring)
**WordPress** : CMS pour la création et la gestion de contenu.
**MySQL** : Base de données relationnelle pour WordPress.
**phpMyAdmin** : Interface web pour l'administration de MySQL.
**SonarQube** : Outil d'analyse de la qualité du code.
**PostgreSQL** : Base de données pour SonarQube.
**Traefik** : Reverse-proxy et gestion SSL.
**LetsEncrypt** (via Traefik) : Pour la gestion des certificats SSL.
**Trivy**: Scanne la vulnérabilité du code via github action
**Duckdns**: Outil open source pour la gestion de dns avec wildcard 


 ## 3. Utilisation du projet
Il est essentiel de vérifier avant tout, le dossier ./helm_thechosen avec lequel, même sans modification de la configuration actuelle, les secrets et les variables doivent impérativement être configurés pour le bon fonctionnement de la stack.


## 3.1. Création des ressources avec Terraform  

Après avoir cloné le dépôt Git du projet à l’adresse ci-dessous et en supposant que vous avez déjà créé votre dépôt git pour ce projet, la première étape est de prendre connaissance du fichier main.tf dans le répertoire correspondant ./production_tf. Si vous utilisez un autre provider que AWS, il suffit d’adapter la configuration de ce fichier selon la documentation de votre provider. Sinon, vous n’avez rien à faire.
* **Dépôt Git**: git@github.com:L-Christ-ASD/thechosen-rke2.git
**PS**:
Il est nécessaire de configurer vos credentials aws dans les variables et secrets de votre dépôt git que vous aurez créer sur github, dans settings -> secrets and variables. Ces variables doivent être définis tels que:  
secrets.AWS_ACCESS_KEY_ID, secrets.AWS_SECRET_ACCESS_KEY et  vars.AWS_DEFAULT_REGION.  Si vous décidez de les nommer autrement, pensez à modifier la tâche “name: Configurer AWS CLI” dans le fichier ./.github/workflows/aws_push.yml avec vos nouveaux noms de variables.


## 3.2. Configuration des services
Vous trouverez toutes les configurations dans le dossier ./helm_thechosen/*, pour la configuration et le déploiement via helm. Toute la configuration peut être adaptée selon le besoin.


## 3.3. Reverse-proxy et DNS
Ce projet utilise Traefik comme reverse proxy et duckdns pour l’enregistrement des noms de domaines. Les deux outils sont open source.
Créez un compte sur duckdns.org et enregistrez un nom de domaine. Celà génère automatiquement un token avec lequel, il faudra mettre à jour le DNS TOKEN dans les secrets ./helm_thechosen/traefik/templates/secret.yaml


**PS**:
Duckdns impose un préfixe dns.duckdns.org. Vous pouvez éviter celà en utilisant un fournisseur dns adapté comme CloudFlare et dans ce cas, pensez à adapter la configuration de traefik et mettre à jour le fichier secret.yaml


## 3.4. Configuration avec ansible
Le dossier ./ansible_production contient les configurations et les tâches  nécessaires pour configurer et installer automatiquement les dépendances nécessaires, ainsi que  la mise en place du cluster rke2.


## 4. Déploiement
Après avoir vérifié et adapté les configurations selon le besoin, pousser le projet vers la branche main de votre dépôt git et la ci/cd va se déclencher automatiquement pour lancer l'exécution des différents fichiers des configurations, afin de déployer les services. Accédez ensuite à vos services selon le DNS configuré pour chaque service.


## 5. Schéma du projet
Voir Schéma de l’infrastructure facette B p.18

## 6. Résultats du projet
***