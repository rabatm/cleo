#!/bin/zsh
# Cree (une seule fois) un certificat de signature auto-signe "Cleo Dev" dans le trousseau login.
# Signer Cleo avec une identite stable evite de re-autoriser l'acces au trousseau a chaque rebuild.
set -euo pipefail

NAME="Cleo Dev"
KC="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning "$KC" | grep -q "$NAME"; then
    echo "Identite '$NAME' deja presente."; exit 0
fi

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cd "$TMP"
openssl req -x509 -newkey rsa:2048 -nodes -keyout key.pem -out cert.pem -days 3650 \
    -subj "/CN=$NAME" -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning"
openssl pkcs12 -export -legacy -inkey key.pem -in cert.pem -out cleo.p12 -passout pass:cleo
security import cleo.p12 -k "$KC" -P cleo -T /usr/bin/codesign
# Fait confiance a ce certificat pour la signature de code uniquement (demande ton mot de passe).
security add-trusted-cert -r trustRoot -p codeSign -k "$KC" cert.pem
security find-identity -v -p codesigning
