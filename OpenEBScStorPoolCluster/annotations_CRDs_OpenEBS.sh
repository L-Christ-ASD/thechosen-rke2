
#!/bin/bash

echo "=========================="
echo "  Étape : Attendre les ressources RKE2 + Corriger les annotations CRDs OpenEBS"
echo "=========================="

# Permet ainsi d'éviter les conflits entre les crds de openebs et ceux de k8s.
# Liste des CRDs attendues
CRDS=(
  volumesnapshotclasses.snapshot.storage.k8s.io
  volumesnapshotcontents.snapshot.storage.k8s.io
  volumesnapshots.snapshot.storage.k8s.io
)

# Fonction d'attente pour les CRDs, avec un timout de 60s
echo "Attente que les CRDs volumesnapshot* soient créées..."
for crd in "${CRDS[@]}"; do
  echo -n "En attente de $crd ... "
  timeout 60 bash -c "until kubectl get crd $crd &>/dev/null; do sleep 2; done" \
    && echo "✅ OK" || echo "❌ Timeout (60s)"
done

# Correction des annotations des CRDs
echo -e "\n Correction des annotations CRDs volumesnapshot..."
for crd in "${CRDS[@]}"; do
  if kubectl get crd "$crd" &>/dev/null; then
    echo "✅ CRD $crd trouvée - correction des annotations"
    kubectl annotate crd "$crd" meta.helm.sh/release-name- --overwrite
    kubectl annotate crd "$crd" meta.helm.sh/release-namespace- --overwrite
    kubectl annotate crd "$crd" meta.helm.sh/release-name=openebs --overwrite
    kubectl annotate crd "$crd" meta.helm.sh/release-namespace=openebs --overwrite
  fi
done

# Attente du deployment rke2-snapshot-controller (éventuel)
echo -e "\n Attente du deployment rke2-snapshot-controller..."
timeout 60 bash -c "until kubectl get deployment rke2-snapshot-controller -n kube-system &>/dev/null; do sleep 2; done"

# Annoter le deployment si trouvé
if kubectl get deployment rke2-snapshot-controller -n kube-system &>/dev/null; then
  echo "Annotation du deployment rke2-snapshot-controller"
  kubectl annotate deployment rke2-snapshot-controller meta.helm.sh/release-name=openebs --overwrite -n kube-system
  kubectl annotate deployment rke2-snapshot-controller meta.helm.sh/release-namespace=openebs --overwrite -n kube-system
else
  echo "Deployment rke2-snapshot-controller non trouvé après 60s — peut être trop lent à démarrer"
fi

echo -e "\n✅ Toutes les annotations nécessaires ont été appliquées"



# #!/bin/bash

# echo "=========================="
# echo "  Étape : Modifier toutes les annotations CRDs OpenEBS automatiquement"
# echo "=========================="

# # Annoter automatiquement tous les CRDs qui concernent les volumesnapshots
# for crd in $(kubectl get crd | grep volumesnapshot | awk '{print $1}'); do
#   echo "Annoter CRD : $crd"
#   kubectl annotate crd "$crd" meta.helm.sh/release-name=openebs --overwrite
#   kubectl annotate crd "$crd" meta.helm.sh/release-namespace=openebs --overwrite
# done

# # Vérifier si le deployment "rke2-snapshot-controller" existe
# if kubectl get deployment rke2-snapshot-controller -n kube-system &> /dev/null; then
#   echo "Annoter deployment rke2-snapshot-controller (kube-system)"
#   kubectl annotate deployment rke2-snapshot-controller meta.helm.sh/release-name=openebs --overwrite -n kube-system
#   kubectl annotate deployment rke2-snapshot-controller meta.helm.sh/release-namespace=openebs --overwrite -n kube-system
# else
#   echo "Deployment rke2-snapshot-controller non trouvé, aucune annotation nécessaire."
# fi

# echo "Toutes les annotations nécessaires ont été appliquées ✅"

