name: SonarQube Analysis

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

jobs:
  sonar:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Run SonarQube Analysis
        run: |
          docker run --rm \
            -e SONAR_HOST_URL="http://sonarqube.christ-devops.duckdns.org" \
            -e SONAR_TOKEN="${{ secrets.SONAR_TOKEN }}" \
            -v "$PWD:/usr/src" \
            sonarsource/sonar-scanner-cli \
            -Dsonar.projectKey=my-project
