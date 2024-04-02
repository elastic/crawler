#!/bin/bash

set -e

echo "Generating an SSL key..."
openssl genrsa -out example.key 2048

echo "Generating a CSR..."
openssl req -new -key example.key -out example.csr -config example.cnf

echo "Generating a Certificate (enter 13243546 when asked for a password)..."
openssl x509 -req \
             -in example.csr \
             -CA ../ca.crt \
             -CAkey ../ca.key \
             -set_serial 123456789 \
             -out example.crt \
             -days 9999 \
             -sha256
