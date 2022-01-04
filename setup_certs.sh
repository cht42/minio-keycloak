#!/bin/bash

mkdir -p certs/{ca,keycloak}

# Choose an appropriate DN
CERTS_DN="/C=UN/ST=UN/L=UN/O=UN"

# Generate root CA (ignore if you already have one)
openssl genrsa -out certs/ca/ca.key 2048
openssl req -new -x509 -sha256 -days 1095 -subj "$CERTS_DN/CN=CA" -key certs/ca/ca.key -out certs/ca/ca.pem

# Generate Keycloak certificate, signed by your CA
openssl genrsa -out certs/keycloak/keycloak-temp.key 2048
openssl pkcs8 -inform PEM -outform PEM -in certs/keycloak/keycloak-temp.key -topk8 -nocrypt -v1 PBE-SHA1-3DES -out certs/keycloak/keycloak.key
openssl req -new -subj "$CERTS_DN/CN=keycloak" -key certs/keycloak/keycloak.key -out certs/keycloak/keycloak.csr
openssl x509 -req -extfile <(printf "subjectAltName=IP:127.0.0.1,IP:172.17.0.1") -in certs/keycloak/keycloak.csr -CA certs/ca/ca.pem -CAkey certs/ca/ca.key -CAcreateserial -sha256 -out certs/keycloak/keycloak.pem
rm certs/keycloak/keycloak-temp.key certs/keycloak/keycloak.csr

# Configuring filenames and rights for Keycloak container
cp certs/keycloak/keycloak.key certs/keycloak/tls.key
cp certs/keycloak/keycloak.pem certs/keycloak/tls.crt
chmod 655 certs/keycloak/tls.crt certs/keycloak/tls.key

