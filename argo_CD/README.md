
### Astuce  

L’erreur ComparisonError: failed to list refs: authentication required: Repository not found indique que le dépôt GitHub est privé ou inaccessible, et qu’ArgoCD n’a pas les identifiants nécessaires pour y accéder.  


ajouter le dépôt avec authentification  

**Option 1**: via HTTPS + token GitHub  

Crée un Personal Access Token (PAT) sur GitHub avec les droits repo.

Ajoute le dépôt dans ArgoCD :

```bash
argocd repo add https://github.com/L-Christ-ASD/thechosen-rke2 \
  --username L-Christ-ASD \
  --password <TON_PAT>
```  

> Si tu utilises GitHub avec l’authentification à deux facteurs, le mot de passe doit être remplacé par le token.

**Option 2** : via SSH
Ajoute une clé SSH privée dans ArgoCD :

```bash
argocd repo add git@github.com:L-Christ-ASD/thechosen-rke2.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```  
Assure-toi que la clé publique est bien ajoutée dans les paramètres du dépôt GitHub.

#### Astuce bonus  

Tu peux aussi ajouter le dépôt via l’interface web ArgoCD :

* Va dans Settings → Repositories

* Clique sur Connect Repo

* Choisis HTTPS ou SSH

* Renseigne les identifiants