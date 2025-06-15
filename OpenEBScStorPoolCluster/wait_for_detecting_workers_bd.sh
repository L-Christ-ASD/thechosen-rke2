#!/bin/bash



# Namespace où se trouvent les blockdevices (souvent openebs)
NAMESPACE="openebs"

# Identifiants des workers
WORKERS=("worker1" "worker2")

# Attente max en secondes (optionnel)
TIMEOUT=500
INTERVAL=30
elapsed=0

echo "Attente que les BlockDevices des workers soient détectés..."

# Boucle infinie jusqu’à ce que tous les blockdevices soient présents ou que le TIMEOUT soit atteint.
# Réinitialise la variable pending, qui indique s’il manque un blockdevice pour un worker.
while true; do
    pending=0

    # Récupère tous les BlockDevices (kubectl get bd) dans le namespace.
    # Filtre ceux liés à ce worker
    # Compte combien il y en a.
    for worker in "${WORKERS[@]}"; do
        # Vérifie si un blockdevice de ce worker existe
        worker_pending=$(kubectl get bd -n "$NAMESPACE" --no-headers | grep "$worker" | wc -l)

        # Si aucun blockdevice n’est trouvé pour ce worker, on le signale et on marque pending=1  (au moins un problème).
        if [ "$worker_pending" -eq 0 ]; then
            echo "Aucun blockdevice trouvé pour $worker."
            pending=1
        fi
    done

    # Si aucun problème (pending=0), tous les blockdevices sont présents, on quitte la boucle avec succès.
    if [ "$pending" -eq 0 ]; then
        echo "✅ Tous les BlockDevices des workers sont détectés."
        break
    fi

    # Si le temps d’attente a dépassé le TIMEOUT, on affiche les blockdevices présents et on termine le script avec une erreur.
    if [ "$elapsed" -ge "$TIMEOUT" ]; then
        echo "❌ Timeout atteint après $TIMEOUT secondes. Certains BlockDevices des workers n'ont pas été trouvés."
        kubectl get bd -n "$NAMESPACE"
        exit 1
    fi

    # Pause avant la prochaine tentative, et on met à jour le temps écoulé.
    sleep "$INTERVAL"
    elapsed=$((elapsed + INTERVAL))
done


# Ce script Bash est conçu pour attendre que les BlockDevices (disques physiques(aws-ebs) détectés par OpenEBS) soient bien visibles dans Kubernetes pour chacun des nœuds worker spécifiés
# Vérifie que chaque worker a au moins un BlockDevice.
# Réessaie toutes les INTERVAL secondes jusqu'à un TIMEOUT
# Attend dynamiquement l'état "prêt" de OpenEBS pour le PVC du cluster.