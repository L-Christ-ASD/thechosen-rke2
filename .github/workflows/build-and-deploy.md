---
name: Deploy on kourou(Self-Hosted)

on:
  push:
  

jobs:
  deploy:
    name: Build and Deploy on Self-Hosted Runner
    runs-on: Self-Hosted # Utilise un runner auto-hébergé, ou ubuntu-24.04 

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      #- name: Create letsencrypt directory
      #  run: mkdir -p /home/student/actions-runner-wpTest/_work/wordPress/wordPress/letsencrypt/

      - name: Show containeur
        run: docker ps -a || true

      - name: Whoami ?
        run: whoami

      - name: Which groups ?
        run: groups

      #- name: vérifie with sonarqube
      #  run: ./make sonar-scan
    
      - name: Take permissions to delete!
        run: sudo usermod -aG docker $USER

      - name: Remove Old Container
        run: |      
          docker ps -q | xargs -r docker stop
          docker ps -aq | xargs -r docker rm -f
          docker system prune -f
          docker system prune -a -f
          docker volume ls -q | xargs -r docker volume rmdocker ps -q | xargs -r docker stop
          docker ps -aq | xargs -r docker rm -f
          docker system prune -f
          docker system prune -a -f
          docker volume ls -q | xargs -r docker volume rm

      - name: Remove Old images 
        run: |
          docker image prune -a -f || true
        
      - name: Run container
        run: |
          docker compose up -d || true

      - name: Check new containeur
        run: |
          docker ps -a || true
       

