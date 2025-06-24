![CI/CD The Chosen](https://github.com/L-Christ-ASD/thechosen-rke2/actions/workflows/aws_push.yml/badge.svg)

![push to dockerhub](https://github.com/L-Christ-ASD/thechosen-rke2/actions/workflows/push-dockerhub.yml/badge.svg)
![Create automatic release](https://github.com/L-Christ-ASD/thechosen-rke2/actions/workflows/TheChosen1.yml/badge.svg)
![the Chosen1 ci/cd](https://github.com/L-Christ-ASD/thechosen-rke2/actions/workflows/trivy.yml/badge.svg)


# Solution cms (WordPress) avec une architecture trois tiers
Déploiement avec **kubernetes rke2**

## 1. Introduction
Ce document présente un projet automatisé du déploiement (mise en production/staging) d’une stack complète offrant une solution cms (WordPress) avec une architecture trois tiers (front, back,bdd) et une solution de supervision des services, via kubernetes k8s. Le cluster est constitué de cinq nœuds dont trois masters et deux workers, configurés automatiquement sur les instances ec2 avec le provider aws via ansible.  Afin de favoriser la flexibilité et la migration de ce projet, le cluster est configuré en mode **self-maged** en **haute disponibilité** et donc, n’est pas attaché à un provider donné. Les technologies utilisées dans la stack et les configurations peuvent-être remplacées ou modifiées pour adapter le projet selon le besoin.  

**PS**:  
Provieder actuel: **ASW**.


## 2. Prérequis:  
Pour faciliter une bonne prise en main de ce projet, il est recommandé d’avoir certaines connaissances et notions (avancées) sur kubernetes, et sur les outils annoncés dans les technologies utilisées. 


* *Matériels*: Terminal, éditeur de texte et navigateur web.


## 5. Technologies utilisées:  

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
**Duckdns**: Outil open source pour la gestion de dns avec wildcard  (limité et idéal pour les tests)


## 4. Schéma du projet
![Schéma rke2](./images/rke2.png)

 ## 5. Utilisation du projet
Il est essentiel de vérifier avant tout, le dossier ./helm_thechosen avec lequel, même sans modification de la configuration actuelle, les secrets et les variables doivent impérativement être configurés pour le bon fonctionnement de la stack.


## 5.1. Création des ressources avec Terraform  

Après avoir cloné le dépôt Git du projet et en supposant que vous avez déjà créé votre dépôt git pour ce projet, la première étape est de prendre connaissance du fichier main.tf dans le répertoire correspondant ./production_tf. Si vous utilisez un autre provider que AWS, il suffit d’adapter la configuration de ce fichier selon la documentation de votre provider. Sinon, vous n’avez rien à faire pour cette partie.  

**PS**:
Il est nécessaire de configurer vos credentials aws dans les variables et secrets de votre dépôt git que vous aurez créer sur github, dans settings -> secrets and variables. Ces variables doivent être définis tels que:  
secrets.AWS_ACCESS_KEY_ID, secrets.AWS_SECRET_ACCESS_KEY et  vars.AWS_DEFAULT_REGION.  Si vous décidez de les nommer autrement, pensez à modifier la tâche “name: Configurer AWS CLI” dans le fichier ./.github/workflows/aws_push.yml avec vos nouveaux noms de variables.


## 5.2. Configuration des services
Vous trouverez toutes les configurations dans le dossier ./helm_thechosen/*, pour la configuration et le déploiement via helm. Toute la configuration peut être adaptée selon le besoin.


## 5.3. Reverse-proxy et DNS
Ce projet utilise Traefik comme reverse proxy et duckdns pour l’enregistrement des noms de domaines. Les deux outils sont open source.
Créez un compte sur duckdns.org et enregistrez un nom de domaine. Celà génère automatiquement un token avec lequel, il faudra mettre à jour le DNS TOKEN dans les secrets ./helm_thechosen/traefik/templates/secret.yaml


**PS**:
Duckdns impose un préfixe dns.duckdns.org. Vous pouvez éviter celà en utilisant un fournisseur dns adapté comme CloudFlare et dans ce cas, pensez à adapter la configuration de traefik et mettre à jour le fichier secret.yaml


## 5.4. Configuration avec ansible
Le dossier ./ansible_production contient les configurations et les tâches  nécessaires pour configurer et installer automatiquement les dépendances nécessaires, ainsi que  la mise en place du cluster rke2.


## 6. Déploiement
Après avoir vérifié et adapté les configurations selon le besoin, pousser le projet vers la branche main de votre dépôt git et la ci/cd va se déclencher automatiquement pour lancer l'exécution des différents fichiers des configurations, afin de déployer les services. Accédez ensuite à vos services selon le DNS configuré pour chaque service.

**PS**:  
Au vu de la configuration et des outils utilisés, ce projet est idéale pour un "**Blue/Green** *Deployment*".


## 7. Vérifications  


7.1. **pods**:  
![pods](./images/pods-rke2.png)  

7.2. **Nodes-k8s**:  
![nodes](./images/nodes.png)  

7.3. **OpenEbs**:  
![OpenEbs](./images/pods-openebs-rke2.png)  

7.4. **Services the_chosen**:  
    *Traefik + nlb + eip*  
![svc](./images/svc.png) 

7.4. **Services ArgoCD**:  
![ArgoSVC](./images/svc-argo.png) 


## 8. Résultats du projet  

8.1. **Wordpress-config**:  
![Wordpress](./images/wordpress-acueil.png)  

8.2. **Site Wordpress**:
![Wordpress-site](./images/monsite2.png)  

8.3. **Traefik**:
![Traefike](./images/traf1.png)  

8.4. **Traefik - Kubernetes crds**:  
![Traefike](./images/traf-k.png)  

Comme l'indiquent les résultats ci-dessus, le déploiement rke2 est un **succès**!!!

Fin du déploiement !