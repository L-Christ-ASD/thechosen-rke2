---
name: Create automatic release for the chosen-rke2
    

on:
    push:
      branches:
        - main
  
permissions:
    contents: write
    pull-requests: write
  
  
jobs:
    release-test:
      runs-on: ubuntu-latest

      steps:
        - name: "Build & test"
          run: |
            echo "done!"

        - uses: googleapis/release-please-action@v4
          with:
            # this assumes that you have created a personal access token
            # (PAT) and configured it as a GitHub action secret named
            # `MY_RELEASE_PLEASE_TOKEN` (this secret name is not important).
            token: ${{ secrets.MY_RELEASE_THECHOSEN_RKE2 }}
            # this is a built-in strategy in release-please, see "Action Inputs"
            # for more options
            release-type: simple
            skip-github-release: false
            skip-github-pull-request: false
            #repo-url: thechosend01/thechosen1