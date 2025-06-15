#!/bin/sh

    if [ ! -f "/letsencrypt/acme.json" ]; then
        touch /letsencrypt/acme.json
    fi
    chmod 600 /letsencrypt/acme.json
    exec traefik "$@"