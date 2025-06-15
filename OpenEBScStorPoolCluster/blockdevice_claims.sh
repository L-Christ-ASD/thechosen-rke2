#!/bin/bash

# Récupère les noms des BlockDevices pour worker1 et worker2
worker1_devices=$(kubectl get blockdevice -n openebs --no-headers | grep worker1 | awk '{print $1}')
worker2_devices=$(kubectl get blockdevice -n openebs --no-headers | grep worker2 | awk '{print $1}')

# Créer un fichier YAML pour les BlockDeviceClaims
output_file="blockdevice_claims.yaml"

# Fonction pour générer un BDC
generate_bdc() {
    local device_name=$1
    cat <<EOF
apiVersion: openebs.io/v1alpha1
kind: BlockDeviceClaim
metadata:
  name: bdc-${device_name}
  namespace: openebs
spec:
  blockDeviceName: ${device_name}
  resources:
    requests:
      storage: "55Gi"
  deviceClaimDetails:
    allowPartition: false
    blockVolumeMode: "BlockVolumeModeBlock"

---
EOF
}

# Créer le fichier YAML vide au début
> $output_file

# Générer les BDCs pour worker1
for device in $worker1_devices; do
    echo "Génération du BlockDeviceClaim pour ${device} sur worker1..."
    generate_bdc $device >> $output_file
done

# Générer les BDCs pour worker2
for device in $worker2_devices; do
    echo "Génération du BlockDeviceClaim pour ${device} sur worker2..."
    generate_bdc $device >> $output_file
done

echo "✅ Les BlockDeviceClaims ont été générés et enregistrés dans ${output_file}."

echo "Vérifier la présence de ${output_file}"
cat ./blockdevice_claims.yaml

echo "Appliquer le fichier ${output_file}"
kubectl apply -f ./blockdevice_claims.yaml




#   Ne génère un BDC que pour les blockdevices Unclaimed sur les nodes worker1 et worker2 uniquement.
#   Produit un fichier blockdevice_claims.yaml conforme à la spec v1alpha1.

# #!/bin/bash

# output_file="blockdevice_claims.yaml"

# # Filtrer uniquement les blockdevices sur worker1 et worker2 avec CLAIMSTATE=Unclaimed
# unclaimed_worker1=$(kubectl get blockdevice -n openebs --no-headers | awk '$2 == "worker1" && $4 == "Unclaimed" {print $1}')
# unclaimed_worker2=$(kubectl get blockdevice -n openebs --no-headers | awk '$2 == "worker2" && $4 == "Unclaimed" {print $1}')

# # Fonction pour générer un BDC
# generate_bdc() {
#     local device_name=$1
#     cat <<EOF
# apiVersion: openebs.io/v1alpha1
# kind: BlockDeviceClaim
# metadata:
#   name: bdc-${device_name}
#   namespace: openebs
# spec:
#   blockDeviceName: ${device_name}
#   resources:
#     requests:
#       storage: "10Gi"
#   deviceClaimDetails:
#     allowPartition: false
#     blockVolumeMode: "BlockVolumeModeBlock"

# ---
# EOF
# }

# # Réinitialiser le fichier YAML
# > "$output_file"

# # Générer les BDCs pour worker1
# for device in $unclaimed_worker1; do
#     echo "Génération du BlockDeviceClaim pour ${device} sur worker1..."
#     generate_bdc $device >> "$output_file"
# done

# # Générer les BDCs pour worker2
# for device in $unclaimed_worker2; do
#     echo "Génération du BlockDeviceClaim pour ${device} sur worker2..."
#     generate_bdc $device >> "$output_file"
# done

# echo "✅ Les BlockDeviceClaims ont été générés dans : $output_file"
