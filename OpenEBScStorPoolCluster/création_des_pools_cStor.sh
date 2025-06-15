#!/bin/bash

# Définir les noms des nœuds et le mode RAID souhaité
NODES=("worker1" "worker2")
RAID_MODE="stripe"

# Initialisation du fichier YAML
cat <<EOF > cstor-pool.yaml
apiVersion: cstor.openebs.io/v1
kind: CStorPoolCluster
metadata:
  name: cstor-disk-pool
  namespace: openebs
spec:
  pools:
EOF

# Supprimer les block devices inactifs
# echo "Suppression des block devices inactifs..."
# kubectl get blockdevices -n openebs -o wide | awk '{print $1}' | xargs -I {} kubectl delete blockdevice {} -n openebs
# sleep 5

for NODE in "${NODES[@]}"; do
  echo "Recherche des block devices pour $NODE..."

  # Récupérer les blockdevices actifs sur chaque nœud
  BLOCK_DEVICES=$(kubectl get blockdevices -n openebs -o wide | grep "$NODE" | awk '{print $1}')

  if [[ -z "$BLOCK_DEVICES" ]]; then
      echo "❌ Aucun block device trouvé sur $NODE. Vérifie NDM (Node Disk Manager)."
      continue
  fi

  echo "✅ Block devices trouvés sur $NODE :"
  echo "$BLOCK_DEVICES"

  # Ajouter le blockdevice actif à la définition du pool
  echo "  - nodeSelector:
      kubernetes.io/hostname: \"$NODE\" 
    dataRaidGroups:
      - blockDevices:" >> cstor-pool.yaml

  # Ajouter les blockdevices pour ce node
  for DEVICE in $BLOCK_DEVICES; do
      echo "          - blockDeviceName: \"$DEVICE\"" >> cstor-pool.yaml
      kubectl patch blockdevice "$DEVICE" -n openebs -p '{"spec":{"claimed":true}}'
  done

  # Ajouter la configuration du pool
  echo "    poolConfig:
      dataRaidGroupType: \"$RAID_MODE\"" >> cstor-pool.yaml
done


# Protection contre CSPC vide
if ! grep -q "blockDeviceName" cstor-pool.yaml; then
  echo "❌ Aucun block device détecté sur aucun worker. Abandon."
  exit 1
fi

# Afficher que la génération est réussie
echo "✅ Fichier 'cstor-pool.yaml' généré avec succès."

# Afficher le contenu du YAML
cat cstor-pool.yaml

# Appliquer le pool
echo "📦 Application du pool..."
kubectl apply -f cstor-pool.yaml



# permettra de redémarrer le processus de gestion du périphérique par OpenEBS et de forcer l'état "Active":
# kubectl patch blockdevice <blockdevice-name> -n openebs -p '{"spec":{"claimed":true}}'
