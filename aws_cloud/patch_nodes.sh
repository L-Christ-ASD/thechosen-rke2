#!/bin/bash

echo "[+] Récupération des correspondances EC2 (IP privée <-> Instance ID)..."
declare -A aws_map

# Remplit un dictionnaire associant IP privée => Instance ID
while read -r instance_id ip; do
    aws_map["$ip"]="$instance_id"
done < <(aws ec2 describe-instances \
    --query "Reservations[].Instances[].[InstanceId,PrivateIpAddress]" \
    --output text)

echo "[+] Association avec les nœuds Kubernetes..."

# Parcourt les nœuds Kubernetes
kubectl get nodes -o wide --no-headers | while read -r node_name status roles age version internal_ip _; do
    instance_id="${aws_map[$internal_ip]}"
    
    if [[ -n "$instance_id" ]]; then
        echo "[>] Patch du nœud $node_name avec providerID aws:///$instance_id"
        
        kubectl patch node "$node_name" -p "{\"spec\":{\"providerID\":\"aws:///$instance_id\"}}"

        echo "[✔] $node_name patché avec providerID et taint à supprimer"

        # Vérifie si le taint est présent avant de tenter de le supprimer
        taint_exists=$(kubectl describe node "$node_name" | grep "node.cloudprovider.kubernetes.io/uninitialized:NoSchedule")
        if [ -n "$taint_exists" ]; then
            # Supprime le taint "uninitialized" s'il est encore présent
            kubectl taint nodes "$node_name" "node.cloudprovider.kubernetes.io/uninitialized:NoSchedule-"
            echo "[✔] $node_name patché avec providerID et taint à supprimer"
        else
            echo "[!] Le taint n'existe pas sur $node_name"
        fi
    else
        echo "[!] Aucune correspondance trouvée pour $node_name ($internal_ip)"
    fi
done
