#!/usr/bin/env bash

# //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#  Todo intodroduce run script 'setup-db-backup' to composer 'scripts' events
#  "scripts": {
#    "post-install-cmd": [
#      \[...\]
#      "@setup-db-backup"
#    ],
#    "post-update-cmd": [
#      \[...\]
#      "@setup-db-backup"
#    ],
#    \[...\]
#    ],
#    "setup-db-backup": [
#      "if [[ -d .db ]] && [[ ! -L .db/wp-db-backup.sh ]]; then ln -s vendor/dennyweiss/laradock-configuration/src/wp-db-backup.sh .db/wp-db-backup.sh; fi"
#    ]
#  }
# //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

set -e
set -o pipefail

SCRIPT_PATH="${0}"
BACKUP_DIR="$(dirname "${SCRIPT_PATH}")"
RESOLVED_PROJECT_ROOT="$(dirname "${BACKUP_DIR}")"

PROJECT_ROOT="${PROJECT_ROOT:-${RESOLVED_PROJECT_ROOT}}"
cd "${PROJECT_ROOT}" || ( echo -e "ERROR: could not move to project directory '${PROJECT_ROOT}'"; exit 1 )

# shellcheck disable=SC1091
source .env || ( echo -e "ERROR: could not load .env file"; exit 1 )

WP_BINARY="{WP_BINARY:-wp}"

case "${WP_ENV}" in
  development)
  WP_BINARY='wp'
  ;;
  staging|production)
  WP_BINARY="${HOME}/.local/share/wp"
  ;;
  *)
  echo -e "ERROR: WP_ENV '${WP_ENV}' not supported"
  exit 1
  ;;
esac

cd .db || ( echo -e "ERROR: could not move to backup directory '${PROJECT_ROOT}/.db'"; exit 1 )

$WP_BINARY db export "${WP_ENV:-environment-unkown}_$(date "+%Y%m%d-%H%M%S").sql" --add-drop-table \
|| ( echo -e "ERROR: backup failed"; exit 1 )
