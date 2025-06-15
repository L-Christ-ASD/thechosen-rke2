- name: Création et installation du cluster rke2
  hosts: all
  become: true
  roles:
    - rke2

# ----------------- Installation sur les Masters -----------------
- name: Installer et configurer les Masters RKE2
  hosts: masters
  become: true
  roles:
    - rke2

- name: Récupérer le token RKE2 sur master1
  hosts: masters[0]  # Récupérer depuis le premier master
  become: true
  roles:
    - rke2

- name: Installer et configurer le Worker RKE2
  hosts: workers
  become: true
  roles:
    - rke2

- name: Vérifier la conf du cluster sur master1
  hosts: masters[0]  # Vérification sur le premier master
  become: true
  roles:
    - rke2
