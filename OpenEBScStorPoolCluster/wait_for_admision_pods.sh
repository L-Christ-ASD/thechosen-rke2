#!/bin/bash

echo "Attente que le webhook OpenEBS soit prêt..."

MAX_WAIT=130   # Timeout total en secondes
WAIT_INTERVAL=5
WAITED=0

# Boucle pour attendre que le webhook soit prêt
# Initialise un compteur WAITED à 0, qui servira à mesurer le temps d’attente cumulé.
while true; do
  WAITED=0 

  # Vérifie si le webhook openebs-cstor-admission-server est prêt
  # Récupère les endpoints (points de terminaison) du service admission webhook dans le ns openebs
  # Extrait uniquement le champ subsets dans jsonpath, qui contient les adresses des pods connectés au service
  #  teste si des adresses sont présentes dans subsets → donc si le webhook est bien exposé par un pod en cours de fonctionnement
  # Tant que le webhook n’est pas prêt, tu continue jusqu'au Timeout total.
  while ! kubectl get endpoints openebs-cstor-admission-server -n openebs -o jsonpath='{.subsets}' | grep -q 'addresses'; do
    echo "  → Webhook non prêt, attente de ${WAIT_INTERVAL}s..."
    sleep $WAIT_INTERVAL
    WAITED=$((WAITED + WAIT_INTERVAL))

    # Condition d’arrêt : si le temps cumulé dépasse la durée maximale d’attente,
    # on considère que le webhook ne démarre pas correctement.
    if [ "$WAITED" -ge "$MAX_WAIT" ]; then
      echo "❌ Timeout : le webhook OpenEBS n'est toujours pas prêt après ${MAX_WAIT}s. Redémarrage des pods d'admission OpenEBS..."
      # Redémarre les pods d'admission OpenEBS
      kubectl rollout restart deployment openebs-cstor-admission-server -n openebs
      sleep 10  # Attente de 10 secondes pour que les pods redémarrent
      WAITED=0  # Réinitialise le compteur d'attente
      continue  # Redémarre la boucle pour vérifier à nouveau
    fi
  done

  echo "✅ Webhook OpenEBS disponible."
  break  # Si le webhook est prêt, sortir de la boucle principale
done


# Ce script Bash est une boucle de vérification de disponibilité d’un webhook Kubernetes spécifique : 
# openebs-cstor-admission-server, qui fait partie du système OpenEBS (plus précisément du moteur cStor).