---

name: docker push

on :
    workflow_dispatch:

    push:
      branches:
        - main
        

env:
  REGISTRY: docker.io
  IMAGE_NAME: christasd/wordPress


jobs:
  login:
    runs-on: ubuntu-24.04
    steps:
      - name: checkout-file
        uses: actions/checkout@v4

      - name: Docker meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: |
            "${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}"
          tags: |

            type=raw,value=latest # un tag par default -> type=raw,value=latest 
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
      
      - name: Print Docker tags 
        run: echo "${{ steps.meta.outputs.tags }}"
          

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERUSR }}
          password: ${{ secrets.DOCKERSECRET }}

      - name: Docker info 
        run: docker info

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |   
            ${{ steps.meta.outputs.tags }}
    
          labels: "${{ steps.meta.outputs.labels }}"

          



        