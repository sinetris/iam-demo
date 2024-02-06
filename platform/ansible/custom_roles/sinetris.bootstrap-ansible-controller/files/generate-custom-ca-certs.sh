#!/usr/bin/env bash

# Custom CA certificate generation script.
#
# This script will generate certificates and keys for both root and intermediate
# certificate authorities.
#
# By default, the script will create the files under '$HOME/.config/demo/custom-ca' and 
# certificates CN starting with 'demo'.
#
# PROJECT:  "demo"
# DATA_DIR: "$HOME/.config/${PROJECT}/custom-ca"
#
# The certificates CN and output path may be overridden with the PROJECT and DATA_DIR
# environment variable respectively.
#
# This script used k3s custom CA certificate generator script as inspiration:
# https://raw.githubusercontent.com/k3s-io/k3s/v1.28.5%2Bk3s1/contrib/util/generate-custom-ca-certs.sh

set -Eeuo pipefail
umask 027

timestamp_now=$(date +%s)

TIMESTAMP="${TIMESTAMP:-${timestamp_now}}"
PROJECT="${PROJECT:-demo}"
DATA_DIR="${DATA_DIR:-$HOME/.config/${PROJECT}/custom-ca}"

if type -t openssl-3 &>/dev/null; then
  OPENSSL=openssl-3
else
  OPENSSL=openssl
fi

echo "Using $(type -p ${OPENSSL}): $(${OPENSSL} version)"

echo " - PROJECT: '${PROJECT}' - DATA_DIR: '${DATA_DIR}' - TIMESTAMP: '${TIMESTAMP}' -"

if ! ${OPENSSL} ecparam -name prime256v1 -genkey -noout -out /dev/null &>/dev/null; then
  echo "openssl not found or missing Elliptic Curve (ecparam) support."
  exit 1
fi

${OPENSSL} version | grep -qF 'OpenSSL 3' && OPENSSL_GENRSA_FLAGS=-traditional

mkdir -p "${DATA_DIR}"
cd "${DATA_DIR}"

# Set up temporary openssl configuration
mkdir -p ".ca/certs"
trap "rm -rf .ca" EXIT
touch .ca/index
openssl rand -hex 8 > .ca/serial
cat >.ca/config <<'EOF'
[ca]
default_ca = ca_default
[ca_default]
dir = ./.ca
database = $dir/index
serial = $dir/serial
new_certs_dir = $dir/certs
default_md = sha256
policy = policy_anything
[policy_anything]
commonName = supplied
[req]
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, keyEncipherment, keyCertSign
EOF

# Use existing root CA if present
if [[ -e root-ca.pem ]]; then
  echo "Using existing root certificate"
else
  echo "Generating root certificate authority RSA key and certificate: 'CN=${PROJECT}-root-ca@${TIMESTAMP}'"
  ${OPENSSL} genrsa ${OPENSSL_GENRSA_FLAGS:-} -out root-ca.key 4096
  ${OPENSSL} req -x509 -new -nodes -sha256 -days 7300 \
                 -subj "/CN=${PROJECT}-root-ca@${TIMESTAMP}" \
                 -key root-ca.key \
                 -out root-ca.pem \
                 -config .ca/config \
                 -extensions v3_ca
fi
cat root-ca.pem > root-ca.crt

# Use existing intermediate CA if present
if [[ -e intermediate-ca.pem ]]; then
  echo "Using existing intermediate certificate"
else
  if [[ ! -e root-ca.key ]]; then
    echo "Cannot generate intermediate certificate without root certificate private key"
    exit 1
  fi

  echo "Generating intermediate certificate authority RSA key and certificate: 'CN=${PROJECT}-intermediate-ca@${TIMESTAMP}'"
  ${OPENSSL} genrsa ${OPENSSL_GENRSA_FLAGS:-} -out intermediate-ca.key 4096
  ${OPENSSL} req -new -nodes \
                 -subj "/CN=${PROJECT}-intermediate-ca@${TIMESTAMP}" \
                 -key intermediate-ca.key |
  ${OPENSSL} ca  -batch -notext -days 3700 \
                 -in /dev/stdin \
                 -out intermediate-ca.pem \
                 -keyfile root-ca.key \
                 -cert root-ca.pem \
                 -config .ca/config \
                 -extensions v3_ca
fi
cat intermediate-ca.pem root-ca.pem > intermediate-ca.crt

if [[ ! -e intermediate-ca.key ]]; then
  echo "Cannot generate leaf certificates without intermediate certificate private key"
  exit 1
fi

echo
echo "Show root-ca.crt"
openssl x509 -in root-ca.crt -noout  -subject -issuer
echo
echo "Show intermediate-ca.crt"
openssl x509 -in intermediate-ca.crt -noout  -subject -issuer
echo
echo "Show root-ca.pem"
cat root-ca.pem | openssl crl2pkcs7 -nocrl -certfile  /dev/stdin  | openssl pkcs7 -print_certs -noout
echo "Show intermediate-ca.pem"
cat intermediate-ca.pem | openssl crl2pkcs7 -nocrl -certfile  /dev/stdin  | openssl pkcs7 -print_certs -noout
echo "Show root-ca.pem x509"
cat root-ca.pem | openssl x509 -in /dev/stdin -noout -text | grep "X509v3 extensions" -A 13
echo
echo "Verify CA chain"
openssl verify -CAfile root-ca.pem intermediate-ca.pem

# openssl verify -CAfile root-ca.pem -untrusted intermediate-ca.pem UserCert.pem

echo
echo "Required files are now present in: ${DATA_DIR}"
echo "You should make a copy of the following files to keep in a secure place:"
ls ${DATA_DIR}/root-ca.* ${DATA_DIR}/intermediate-ca.* | xargs -n1 echo -e "\t"
echo
echo "CA certificate generation complete."
