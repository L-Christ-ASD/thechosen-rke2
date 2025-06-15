---

- name: Vérifier la connectivité des hôtes avec Ansible ping
  hosts: all
  gather_facts: false
  tasks:
    - name: ping Ansible hosts
      ansible.builtin.ping:


- name: Installer et configurer RKE2 (HA) sur tous les servers
  hosts: all
  become: true
  tasks:

    - name: Mettre à jour les paquets sans redémarrer les services critiques
      apt:
        update_cache: true
        upgrade: safe

    - name: Désactiver swap temporairement
      command: swapoff -a
      when: ansible_swaptotal_mb > 0

    - name: Désactiver swap de façon permanente
      lineinfile:
        path: /etc/fstab
        regexp: '^\s*[^#].*\bswap\b.*$'
        state: absent

    - name: Installer les dépendances nécessaires
      apt:
        name:
          - curl
          - iptables
          - socat
          - unzip
          - iproute2
        state: present

    - name: Définir le hostname
      command: hostnamectl set-hostname {{ inventory_hostname }}

    - name: Configurer le fichier /etc/hosts
      blockinfile:
        path: /etc/hosts
        block: |
          
          {{ ansible_facts['default_ipv4']['address'] }} {{ inventory_hostname }}
          ::1     ip6-localhost ip6-loopback
          fe00::0 ip6-localnet
          ff00::0 ip6-mcastprefix
          ff02::1 ip6-allnodes
          ff02::2 ip6-allrouters
          {{ hostvars[groups["masters"][0]]["ansible_host"] }} rke2cluster.christ.lan


    - name: Créer le répertoire /etc/rancher/rke2 si nécessaire
      file:
        path: /etc/rancher/rke2
        state: directory
        owner: root
        group: root
        mode: '0755'

    - name: Vérifier si RKE2 est déjà installé
      command: which rke2
      register: rke2_check
      ignore_errors: true
      changed_when: false

    - name: Télécharger et installer RKE2 si nécessaire
      shell: "curl -sfL https://get.rke2.io | INSTALL_RKE2_CHANNEL=stable INSTALL_RKE2_VERSION='v1.30.0+rke2r1' sh -"
      when: rke2_check.rc != 0

    - name: Supprimer le script d'installation temporaire
      file:
        path: /tmp/install-rke2.sh
        state: absent

    #- name: Pause de 60 secondes pour laisser RKE2 s'initialiser
    #  ansible.builtin.pause:
    #    seconds: 60


#-------------------configuration master1-------------------------------


 
    - name: Activer et démarrer le serveur RKE2 master-1
      systemd:
        name: rke2-server
        enabled: true
        state: started

    - name: Pause de 60 secondes pour laisser RKE2-server démarrer
      ansible.builtin.pause:
        seconds: 60

    - name: Vérifier que RKE2 est actif sur master1 (attaendre avant de continuer)
      command: systemctl is-active rke2-server
      register: rke2_status
      until: rke2_status.stdout == "active"
      retries: 10
      delay: 5
      become: true
#-----------------Avant modif--------------------=====================

    - name: Lire rke2.yaml sur master1
      command: cat /etc/rancher/rke2/rke2.yaml
      when: rke2_status.rc == 0
      register: rke2_yaml_content

    - name: Afficher rke2.yaml sur master1
      debug:
        var: rke2_yaml_content.stdout
      when: rke2_status.rc == 0

#=================== Mise à jour du fichier rke2.yml=================

    - name: Mettre à jour le fichier rke2.yaml avec l'IP publique sur master1
      lineinfile:
        path: /etc/rancher/rke2/rke2.yaml
        regexp: '^    server: https://.*:6443'
        line: '    server: https://{{ hostvars[groups["masters"][0]]["ansible_host"] }}:6443'
      when: inventory_hostname == groups['masters'][0]
      become: true

    - name: Lire rke2.yaml sur master1
      command: cat /etc/rancher/rke2/rke2.yaml
      when: rke2_status.rc == 0
      register: rke2_yaml_content

    - name: Afficher rke2.yaml sur master1
      debug:
        var: rke2_yaml_content.stdout
      when: rke2_status.rc == 0

#==================config.yaml=====================
    - name: Lire config.yaml sur master1
      command: cat /etc/rancher/rke2/rke2.yaml
      when: rke2_status.rc == 0
      register: rke2_yaml_content

    - name: Afficher config.yaml sur master1
      debug:
        var: rke2_yaml_content.stdout
      when: rke2_status.rc == 0 

    - name: Configurer /etc/rancher/rke2/config.yaml master1
      copy:
        dest: /etc/rancher/rke2/config.yaml
        content: |
          tls-san:
            - "{{ hostvars[groups['masters'][0]]["ansible_host"] }}"
            - {{ hostvars[groups["masters"][1]]["ansible_host"] }}
            - {{ hostvars[groups["masters"][2]]["ansible_host"] }}
            - rke2cluster.christ.lan
            - master1.christ.lan
            - {{ inventory_hostname }}
            - {{ ansible_facts['default_ipv4']['address'] }}  
          write-kubeconfig-mode: "0644"
      when: inventory_hostname == groups['masters'][0]

    - name: Lire le contenu config.yaml 
      command: cat /etc/rancher/rke2/rke2.yaml 
      when: rke2_status.rc == 0
      register: rke2_yaml_content

    - name: Afficher config.yaml sur master1 après modif
      debug:
        var: rke2_yaml_content.stdout
      when: rke2_status.rc == 0 
#=====================================================
    - name: Redémarrer le serveur RKE2 master1
      systemd:
        name: rke2-server
        enabled: true
        state: restarted

    - name: Pause de 60 secondes pour laisser RKE2-server démarrer
      ansible.builtin.pause:
        seconds: 60

    - name: Attaendre que RKE2 est actif avant de continuer
      command: systemctl is-active rke2-server
      register: rke2_status
      until: rke2_status.stdout == "active"
      retries: 10
      delay: 5
      become: true

    - name: Lire le contenu de /etc/rancher/rke2/config.yaml 
      command: cat /etc/rancher/rke2/rke2.yaml 
      when: rke2_status.rc == 0 

    - name: Afficher rke2.yaml sur master1
      debug:
        var: rke2_token.stdout
      when: rke2_status.rc == 0 

    - name: Vérifier si le fichier node-token existe sur master1
      stat:
        path: /var/lib/rancher/rke2/server/node-token
      register: token_file

    - name: Lire le token RKE2 s'il existe sur master1
      command: cat /var/lib/rancher/rke2/server/node-token
      when: token_file.stat.exists
      register: rke2_token

# ----------------- Récupérer le token automatiquement -----------------

    - name: Vérifier que le service RKE2 est actif sur master1
      command: systemctl status rke2-server
      register: rke2_status
      ignore_errors: true  # Ignore l'erreur si le service est inactif
    
    - name: Lire le token RKE2 sur master1
      command: cat /var/lib/rancher/rke2/server/node-token
      register: rke2_token
      when: rke2_status.rc == 0  # Exécute seulement si le service est actif

    - name: Afficher le token récupéré sur master1
      debug:
        var: rke2_token.stdout
      when: rke2_status.rc == 0  # Affiche seulement si le service est actif

    - name: Partager le token avec les autres hôtes
      set_fact:
        rke2_token_value: "{{ rke2_token.stdout }}"
      when: rke2_status.rc == 0


# ----------------- Installation sur les Masters---------------

- name: Configuration des autres Masters
  hosts: masters #[1:]
  become: true
  tasks:

    - name: Configurer RKE2 sur les autres masters
      copy:
        dest: /etc/rancher/rke2/config.yaml
        content: |
          token: "{{ hostvars[groups['masters'][0]]['ansible_host']['rke2_token_value'] }}"
          tls-san:
            - "{{ hostvars[groups['masters'][0]]['ansible_host'] }}"
            - {{ hostvars[groups["masters"][1]]["ansible_host"] }}
            - {{ hostvars[groups["masters"][2]]["ansible_host"] }}
            - rke2cluster.christ.lan
            - master1.christ.lan
            - {{ inventory_hostname }}
            - {{ ansible_facts['default_ipv4']['address'] }}  
          write-kubeconfig-mode: "0644"
          server: "https://{{ hostvars[groups['masters'][0]]['ansible_host'] }}:6443"
        when: inventory_hostname != groups['masters'][0]

    - name: Mettre à jour le fichier rke2.yaml avec l'IP publique sur master1
      lineinfile:
        path: /etc/rancher/rke2/rke2.yaml
        regexp: '^    server: https://.*:6443'
        line: '    server: https://{{ hostvars[groups["masters"][0]]["ansible_host"] }}:6443'
      when: inventory_hostname != groups['masters'][0]
      become: true        

    - name: Vérifier que le token est bien défini
      debug:
        var: hostvars[groups['masters'][0]]['rke2_token_value']


    - name: Activer et démarrer le serveur RKE2
      systemd:
        name: rke2-server
        enabled: true
        state: started
      when: inventory_hostname != groups['masters'][0]

    - name: Attendre que RKE2 soit actif (master2 et 3)
      command: systemctl is-active rke2-server
      register: rke2_status
      until: rke2_status.stdout == "active"
      retries: 10
      delay: 5
      when: inventory_hostname != groups['masters'][0]
      

    - name: Copier le kubeconfig sur la machine locale depuis le master principal (master1)
      fetch:
        src: /etc/rancher/rke2/rke2.yaml
        dest: ./kubeconfig.yaml
        flat: true
      when: inventory_hostname == groups['masters'][0]


# ----------------- Installation sur le Worker -----------------
- name: Installer et configurer le Worker RKE2
  hosts: workers
  become: true
  tasks:

    - name: Installer les dépendances nécessaires
      apt:
        name:
          - curl
          - iptables
        state: present

    - name: Vérifier si le token a bien été récupéré
      debug:
        var: hostvars[groups['masters'][0]]['rke2_token_value']
    
    - name: Vérifier que le serveur master est bien défini
      debug:
        var: hostvars[groups['masters'][0]]['ansible_host']

    - name: Configurer RKE2 agent
      ansible.builtin.copy:  
        dest: /etc/rancher/rke2/config.yaml
        content: |
          token: "{{ hostvars[groups['masters'][0]]['rke2_token_value'] }}"
          server: "https://{{ hostvars[groups['masters'][0]]['ansible_host'] }}:9345"
        
        
#---------------------------------------------------------------
    - name: Afficher la valeur du token sur les workers
      debug:
        var: hostvars[groups['masters'][0]]['rke2_token_value']
      
#-----------------------------------------------------------

    - name: Pause de 60 secondes pour laisser RKE2-agent s'installer tranquilement!
      ansible.builtin.pause:
        seconds: 60
#
    #- name: Attendre que le worker soit de nouveau accessible en SSH
    #  wait_for_connection:
    #    timeout: 120

    - name: Activer et démarrer RKE2 agent
      systemd:
        name: rke2-agent
        enabled: true
        state: started

    - name: Attendre 60 secondes après le démarrage de RKE2 agent
      pause:
        seconds: 60
#
    #- name: Vérifier que le worker est de nouveau accessible après activation de RKE2 agent
    #  wait_for_connection:
    #    timeout: 180

    - name: Attendre que RKE2-agent soit actif
      command: systemctl is-active rke2-agent
      register: rke2_status
      until: rke2_status.stdout == "active"
      retries: 10
      delay: 5

    - name: Vérifier que le service RKE2-agent est actif sur worker1
      command: systemctl status rke2-agent
      register: rke2_status
      ignore_errors: true  

#===================Vérifs==================================
- name: Installer kubectl et Vérifer que RKE2 fonctionne sur master1
  hosts: masters[0]
  become: true
  tasks:

      # Installer kubectl sur master1
    - name: Télécharger la version stable de kubectl
      command: "curl -L -s https://dl.k8s.io/release/stable.txt"
      register: kubectl_version
      when: inventory_hostname == groups['masters'][0]

    - name: Télécharger kubectl sur master1
      command: "curl -LO https://dl.k8s.io/release/{{ kubectl_version.stdout }}/bin/linux/amd64/kubectl"
      args:
        chdir: /usr/local/bin
      when: inventory_hostname == groups['masters'][0]

    - name: Télécharger le fichier checksum de kubectl
      command: "curl -LO https://dl.k8s.io/release/{{ kubectl_version.stdout }}/bin/linux/amd64/kubectl.sha256"
      args:
        chdir: /usr/local/bin
      when: inventory_hostname == groups['masters'][0]

    - name: Vérification d'intégrité de kubectl sur master1
      command: "echo $(cat kubectl.sha256)  kubectl | sha256sum --check"
      args:
        chdir: /usr/local/bin
      when: inventory_hostname == groups['masters'][0]

    - name: Rendre kubectl exécutable
      command: chmod +x /usr/local/bin/kubectl
      when: inventory_hostname == groups['masters'][0]

    - name: Vérifier l'emplacement de kubectl
      command: which kubectl
      register: kubectl_path
      ignore_errors: true

    - name: Afficher l'emplacement de kubectl
      debug:
        var: kubectl_path.stdout

    - name: Vérifier si kubectl de RKE2 est installé
      stat:
        path: /var/lib/rancher/rke2/bin/kubectl
      register: kubectl_rke2

    - name: Vérifier si le fichier kubeconfig existe
      stat:
        path: /etc/rancher/rke2/rke2.yaml
      register: kubeconfig_file

    - name: Vérifier la configuration du cluster avec kubectl
      command: KUBECONFIG=/etc/rancher/rke2/rke2.yaml kubectl get nodes
      register: kubectl_nodes
      changed_when: false
      when: kubeconfig_file.stat.exists  # Exécute la commande seulement si le fichier existe

    - name: Afficher les nœuds du cluster
      debug:
        var: kubectl_nodes.stdout_lines
      when: kubeconfig_file.stat.exists
    #============================================




#- name: Vérifier que RKE2 fonctionne via master1
#  hosts: "{{ groups['masters'][0] }}"  # Sélectionne directement master1
#  become: true
#  tasks:
#
#    - name: Vérifier si le fichier kubeconfig existe
#      stat:
#        path: /etc/rancher/rke2/rke2.yaml
#      register: kubeconfig_file
#
#    - name: Vérifier que le service RKE2 est actif
#      command: systemctl is-active rke2-server
#      register: rke2_status
#      changed_when: false
#      failed_when: rke2_status.stdout != "active"
#
#    - name: Vérifier la configuration du cluster avec kubectl
#      command: KUBECONFIG=/etc/rancher/rke2/rke2.yaml /var/lib/rancher/rke2/bin/kubectl get nodes
#      register: kubectl_nodes
#      changed_when: false
#      when: kubeconfig_file.stat.exists  # Exécute la commande seulement si le fichier existe
#
#    - name: Afficher les nœuds du cluster
#      debug:
#        var: kubectl_nodes.stdout_lines
#      when: kubeconfig_file.stat.exists
    #- name: Créer un lien symbolique vers kubectl
    #  file:
    #    src: /usr/local/bin/kubectl
    #    dest: /var/lib/rancher/rke2/bin/kubectl
    #    state: link
    #  when: kubectl_rke2.stat.exists





  handlers:
    - name: Reload profile
      shell: source /etc/profile
