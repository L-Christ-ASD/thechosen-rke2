#!/bin/bash

echo "Vérifier l'état des pods dans le namespace openebs"
kubectl get pods -n openebs

TIMEOUT=360
INTERVAL=30
ELAPSED_TIME=0

while true; do
    # Liste les pods OpenEBS sans l'en-tête
    # Extrait la 2e colonne (le champ READY)
    # Filtrer tout ce qui n’est pas une valeur correctement formatée du type X/Y, (par ex. erreurs, champs vides ou en pending).
    # Compte combien de lignes correspondent.
    #
    # De nouveau, on extrait le champ READY (x/y) de chaque pod.
    # Compare les deux chiffres (containers prêts vs. total). Si différents, le pod est partiellement prêt.
    # compte les pods dans ce cas.
    #
    # Additionne les deux résultats pour obtenir le nombre de pods OpenEBS qui ne sont pas prêts
    NOT_READY_COUNT=$(kubectl get pods -n openebs --no-headers | awk '{print $2}' | grep -vE '^[0-9]+/[0-9]+$' | wc -l)
    PARTIALLY_READY=$(kubectl get pods -n openebs --no-headers | awk '{print $2}' | awk -F'/' '$1 != $2' | wc -l)
    TOTAL_NOT_READY=$((NOT_READY_COUNT + PARTIALLY_READY))

    # Condition : s’il n’y a aucun pod non prêt (TOTAL_NOT_READY == 0),
    # Affiche un message de succès et sort de la boucle.
    if [ "$TOTAL_NOT_READY" -eq 0 ]; then
        echo "✅ Tous les pods sont prêts dans openebs."
        break
    fi

    # Si le temps écoulé dépasse le temps limite (TIMEOUT),
    # Affiche un message d’échec, Montre l’état des pods et sort de la boucle. 
    if [ "$ELAPSED_TIME" -ge "$TIMEOUT" ]; then
        echo "❌ Le temps imparti est écoulé, certains pods ne sont pas prêts."
        kubectl get pods -n openebs
        break
    fi

    # Affiche une ligne d’attente avec:
    # le temps déjà écoulé et le nombre de pods encore non prêts
    # Puis attend INTERVAL secondes avant de recommencer la boucle
    # Incrémente la variable ELAPSED_TIME du temps d’attente
    echo "Attente... $ELAPSED_TIME secondes écoulées. Pods non prêts: $TOTAL_NOT_READY"
    sleep $INTERVAL
    ELAPSED_TIME=$((ELAPSED_TIME + INTERVAL))
done



# Ce script permet de surveiller dynamiquement l’état des pods OpenEBS, en détectant tout pod non prêt ou mal démarré.
#  Permet d'attendre que le système soit complètement stable avant de continuer.
# Avec :
# une sortie immédiate dès que tout est prêt,
# un arrêt si ça prend trop longtemps
# des messages réguliers de suivi.


# Explication du motif REGEX(grep -vE '^[0-9]+/[0-9]+$'):

# ^ : début de la ligne
# [0-9]+ : une ou plusieurs chiffres (X)
# / : le caractère slash (séparateur READY)
# [0-9]+ : une ou plusieurs chiffres (Y)
# $ : fin de la ligne
# Donc '^[0-9]+/[0-9]+$' correspond uniquement à des lignes strictement comme 1/1, 0/1, 3/3, etc.

#  -vE
# -E : active les expressions régulières étendues (Extended regex).
# -v : inverse la sélection, i.e. exclut les lignes qui correspondent au motif (comme 1/1, 0/1, 3/3, etc.) pour n'obtenir que Running ou CrashLoopBackOff.


# Explication de la commande awk:
# awk : outil de traitement de texte en ligne très puissant.

# -F'/' : indique que le séparateur de champ est / (par défaut c’est un espace ou une tabulation).
# '$1 != $2' : c’est une condition :
# $1 : la partie avant le /
# $2 : la partie après le /
# != : signifie "différent de"

# Donc awk ne garde que les lignes où les deux valeurs sont différentes.
# On extrait la colonne READY (ex : 1/1, 0/1), et on repère les pods partiellement prêts.
# (ex : 1/1, 0/1) montrent que tous les containers ne sont pas prêts dans ces pods (READY != TOTAL).