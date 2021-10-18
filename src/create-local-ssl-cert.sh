#!/usr/bin/env bash
DOMAINS="${1}"
TARGET_DIRECTORY="${2:-./.services/nginx}"

if ! which mkcert &>/dev/null; then
  echo
  echo "ERROR: 'mkcert' is missing but required for ssl creation"
  exit 1
fi

if [[ ! -d "${TARGET_DIRECTORY}" ]]; then
  mkdir -p "${TARGET_DIRECTORY}"
fi

cd "${TARGET_DIRECTORY}" || exit 1

echo "Generate SSL Certificate"
mkcert \
    -cert-file _wildcard.dev.crt \
    -key-file _wildcard.dev.key \
    "${DOMAINS}" 'localhost' 127.0.0.1 ::1

echo
echo "Copy rootCA.pem"
cp "$(mkcert -CAROOT)/rootCA.pem" .

