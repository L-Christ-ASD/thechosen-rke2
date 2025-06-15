
# Il suffit de décommenter!!!

# ---
#     name: Build and Scan Image with Trivy
    
#     on:
#       push:
        
    
#     jobs:
#       scan:
#         name: Scan Docker Image
#         runs-on: ubuntu-latest
#         steps:
#           - name: Checkout Code
#             uses: actions/checkout@v4
    
#           - name: Build the Docker Image
#             run: |
#               docker build -t christ/apotheos:${{ github.sha }} ./
    
#           - name: Run Trivy Vulnerability Scanner on Image
#             uses: aquasecurity/trivy-action@0.28.0
#             with:
#               image-ref: 'christ/apotheos:${{ github.sha }}'
#               format: 'table'
#               output: 'image-scan-results-${{ github.sha }}.txt'
#               ignore-unfixed: true
#               vuln-type: 'os,library'
#               severity: 'CRITICAL,HIGH,MEDIUM,LOW'
#               #exit-code: 1  # Stop si vulnérabilités détectées
    
#           - name: Run Trivy Vulnerability Scanner on Configuration Files
#             uses: aquasecurity/trivy-action@0.28.0
#             with:
#               scan-type: 'config'
#               hide-progress: true
#               format: 'sarif'
#               output: 'config-scan-results-${{ github.sha }}.sarif'
#               severity: 'CRITICAL,HIGH,MEDIUM,LOW'
    
#           - name: Upload Trivy Image Scan Results.txt
#             uses: actions/upload-artifact@v4
#             with:
#               name: trivy-image-report
#               path: image-scan-results-${{ github.sha }}.txt
    
#           - name: Upload Trivy Config Scan Results.sarif
#             uses: actions/upload-artifact@v4
#             with:
#               name: trivy-config-report
#               path: config-scan-results-${{ github.sha }}.sarif

#           #- name: Upload Trivy Config Scan Results        #Activer l’annotation automatique dans GitHub pour les résultats SARIF          
#           #  uses: github/codeql-action/upload-sarif@v3   # Mise à jour vers v3
#           #  with:
#           #    sarif_file: config-scan-results-${{ github.sha }}.sarif
#           #    token: ${{ secrets.GITHUB_TOKEN }}  # Ajout du token   

#         #permissions:
#         #  security-events: write  # Permet d'envoyer les rapports SARIF à GitHub
#         #  actions: read
#         #  contents: read

          


        

            