# add check| for required main project vars
check_dc_project_name := `if [[ -f '.env' && -z "${DC_PROJECT_NAME}" ]]; then exit 1; fi `
check_active_theme := `if [[ -f '.env' && -z "${WP_ACTIVE_THEME}" ]]; then exit 1; fi `
check_env_dev := `if [[ -f '.env' && -z "${WP_HOME_DEVELOPMENT}" ]]; then exit 1; fi `
check_env_stage := `if [[ -f '.env' && -z "${WP_HOME_STAGING}" ]]; then exit 1; fi `
check_env_prod := `if [[ -f '.env' && -z "${WP_HOME_PRODUCTION}" ]]; then exit 1; fi `

debug-mode := "false"
dry-run := 'false'
dry-run-script := 'if [[ ' + dry-run + ' == "true" ]]; then echo -e "\n!!! dry-run - stop execution!!!\n"; exit 0; fi'

# make docker-path overridable in case of supporting addtional project roots
docker-path :=  env_var_or_default('DC_PATH', '.docker')
move-to-docker-dir := 'cd ' + docker-path + '&& '
docker-compose-project-name := "--project-name ${DC_PROJECT_NAME}"

container-user := env_var_or_default('DC_USER', 'laradock')
set-container-user-parameter-string := "--user='" + container-user + "'"
default-user := set-container-user-parameter-string
default-db-export-filename := "${WP_ENV}" + "_" + `date "+%Y%m%d-%H%M%S"` + '.sql'
default-db-export-filepath := '.db' + "/" + default-db-export-filename
force := "false"
themedir := 'web/app/themes' + "/" + "${WP_ACTIVE_THEME}"
root := 'false'
current_environment := "${WP_ENV-development}"
projectNamePlaceholder := '%%%_PROJECT_NAME_%%%'

indent := "  "
indent2x := indent + indent
task-prefix := '>>' + indent
warn-prefix := indent2x + 'WARN: '

## @info new variables
config-package-path-prefix := 'vendor/dennyweiss/laradock-configuration'
config-package-commands-path-prefix := config-package-path-prefix + '/src/commands'

# Show available commands
default:
  @just --list

alias help := default

# docker-compose shorthand
dc +parameters_and_or_services:
  @docker-compose {{parameters_and_or_services}}

# Start one or more services
up +parameters_and_or_services='':
  @docker-compose up {{ parameters_and_or_services }}

alias start := up

# Start service stack in background
stack-up:
  @'{{config-package-commands-path-prefix}}/docker-compose-stack-up'

alias stackup := stack-up

# Stop running services
stop +parameters_and_or_services='':
  @docker-compose stop {{parameters_and_or_services}}

# Build one or multiple services at a time
build +services='':
  @'{{config-package-commands-path-prefix}}/docker-compose-build' {{services}}

# Shorthand for service stop, build & up again
rebuild service as-daemon='true':
  @'{{config-package-commands-path-prefix}}/docker-compose-rebuild' {{service}} {{as-daemon}}

# Remove all Services, Networks & Volumes
destroy +parameters='':
  @'{{config-package-commands-path-prefix}}/docker-compose-destroy' {{parameters}}

# Execute commands inside running service
exec +parameters_and_or_services:
  @docker-compose exec {{parameters_and_or_services}}

# Run a service without establishing networks
run +parameters_and_or_services:
  @docker-compose run {{parameters_and_or_services}}

# Show status created services
ps +parameters='':
  @docker-compose ps {{parameters}}

alias status := ps

# Show docker-compose config
config-show +parameters='':
  @docker-compose config {{parameters}}

# Show service names that are defined in docker-compose
services-list:
  @docker-compose config --services

# Reload environment variables
reload-environment:  
  @direnv allow .envrc

alias re := reload-environment

# Show logs of running service
log service='':
  @docker-compose logs --follow {{service}}

# Fetch container images from registries
images-prefetch +images: 
  @docker-compose pull {{images}}

# Log into user defined 'USER_DR_URL' docker registry
registry action:
  @'{{config-package-commands-path-prefix}}/docker-registry' {{action}}

# Encrypt or decrypt file
vault action file:
  @'{{config-package-commands-path-prefix}}/vault' {{action}} {{file}}

# Calls composer with parameters inside 'workspace' service
composer +subcommands='':
  @docker-compose exec --user="${COMPOSE_USER:-laradock}" workspace composer {{subcommands}}

# Calls wp-cli with parameters inside 'workspace' service
wp +subcommands='':
  @docker-compose exec --user="${COMPOSE_USER:-laradock}" workspace wp {{subcommands}}

# Calls npm with parameters inside 'workspace' service defaults to themedir
npm +subcommands='':
  @'{{config-package-commands-path-prefix}}/docker-compose-exec-npm' {{subcommands}}

# Opens bash console inside workspace container
bash +subcommands='':
  @docker-compose exec --user="${COMPOSE_USER:-laradock}" workspace bash {{subcommands}}

# @warn below are old definitions

# << // ---- @warn _* helper commands below are potentially obsolete 
_print_title message:
  #!/usr/bin/env bash
  echo ''
  echo "{{task-prefix}}{{message}}"

_print_task_title message:
  #!/usr/bin/env bash
  echo ''
  echo "{{indent2x}} > {{message}}"

_print_task_description message:
  #!/usr/bin/env bash
  echo "{{indent2x}}   {{message}}"

_print_progress_result message:
  #!/usr/bin/env bash
  echo "{{indent2x}}{{indent}} => {{message}}"

_print_ok_end message:
  #!/usr/bin/env bash
  echo ''
  echo "=>{{indent}}{{message}}"

_print_error message:
  #!/usr/bin/env bash
  echo ''
  echo "{{warn-prefix}}{{message}}"
# >> // ---- @warn

# Imports SQL DB from file and applies correct 'WP_HOME'
db-import file:
  #!/usr/bin/env bash
  echo ''
  file="{{file}}"
  echo "{{task-prefix}}Import DB from '${file}'"

  replacement="${WP_HOME}"
  source_wp_homes=( "${WP_HOME_DEVELOPMENT}" "${WP_HOME_STAGING}" "${WP_HOME_PRODUCTION}" )

  if [[ "{{debug-mode}}" == 'true' ]]; then
    echo ''
    echo "{{indent2x}}dry-run:          '{{dry-run}}'"
    echo "{{indent2x}}file:             '${file}'"
    echo "{{indent2x}}replacement:      '${replacement}'"
    echo "{{indent2x}}source_wp_homes:"
    for search in "${source_wp_homes[@]}"; do
      echo "{{indent2x}}                  - '${search}'"
    done
    echo ''
  fi

  if [[ ! -f "${file}" ]]; then
    echo ''
    echo "{{warn-prefix}}SQL File '${file}' not found but required"
    echo ''
    exit 1
  fi

  {{move-to-docker-dir}}
  if [[ "{{dry-run}}" == 'false' ]]; then
    echo ''
    echo "{{indent2x}} > Importing DB"
    result=0
    docker-compose {{docker-compose-project-name}} exec {{default-user}} workspace wp db import "${file}"
    echo ''
    if [[ "${result}" != "0" ]]; then
      echo "{{warn-prefix}}Importing '${file}' failed"
      echo ''
      exit 1
    fi
  else
    echo ''
    echo "{{indent2x}} > (skipped) Importing DB"
    echo ''
  fi

  for search in "${source_wp_homes[@]}"; do
    isrunningdry=''
    if [[ "{{dry-run}}" == 'true' ]]; then
      isrunningdry='(skipped) '
    fi

    echo "{{indent2x}} > ${isrunningdry}Url replacement"
    echo "{{indent2x}}   search:      '${search}'"
    echo "{{indent2x}}   replacement: '${replacement}'"
    echo ''

    result=0
    if [[ "{{dry-run}}" != 'false' ]]; then
      docker-compose {{docker-compose-project-name}} exec {{default-user}} workspace wp search-replace \
        "${search}" \
        "${replacement}" \
        --report-changed-only \
        --skip-columns=guid \
        --dry-run
    else
      docker-compose {{docker-compose-project-name}} exec {{default-user}} workspace wp search-replace \
        "${search}" \
        "${replacement}" \
        --report-changed-only \
        --skip-columns=guid
    fi

    if [[ "${result}" != "0" ]]; then
      echo "{{warn-prefix}}Url replacement failed"
      echo ''
      exit 1
    fi

    echo ''
  done

# Exports SQL DB to file
db-export file=default-db-export-filepath:
  #!/usr/bin/env bash
  echo ''
  filepath="{{file}}"
  directorypath="$(dirname "${filepath}")"
  echo "{{task-prefix}}Export DB to '${filepath}'"

  if [[ "{{debug-mode}}" == 'true' ]]; then
    echo ''
    echo "{{indent2x}}filepath:       '${filepath}'"
    echo "{{indent2x}}directorypath:  '${directorypath}'"
    echo ''
  fi

  if [[ ! -d "${directorypath}" && "{{force}}" == "false" ]]; then
    echo ''
    echo "{{warn-prefix}}SQL File dump directory '${directorypath}' not found but required"
    echo ''
    exit 1
  fi

  if [[ ! -d "${directorypath}" ]]; then
    mkdir -p "${directorypath}"
    if [[ "${?}" != "0" ]]; then
      echo ''
      echo "{{warn-prefix}}Directory for SQL dump could not be created"
      echo ''
      exit 1
    fi
  fi

  if [[ -f "${filepath}" && "{{force}}" == 'false' ]]; then
    echo ''
    echo "{{warn-prefix}}SQL File '${file}' does already exists use 'force=true' option to overide"
    echo ''
    exit 1
  fi

  {{dry-run-script}}
  {{move-to-docker-dir}} docker-compose {{docker-compose-project-name}} exec {{default-user}} workspace wp db export \
    "${filepath}" \
    --add-drop-table

  if [[ "${?}" != "0" ]]; then
    echo "{{warn-prefix}}DB export failed"
    echo ''
    exit 1
  fi

# Calls actions [start|stop|status] on xdebug
xdebug action='status':
  #!/usr/bin/env bash
  action="{{action}}"

  if [[ "${action}" == 'start' || "${action}" == 'stop' || "${action}" == 'status' ]]; then
    {{move-to-docker-dir}} ./php-fpm/xdebug "${action}"
    exit 0
  fi

  echo ''
  echo "{{warn-prefix}}Action '${action}' is not supported" 
  echo ''
  exit 1

# Fetch db, assets & files from remote environment
fetch-from +parameters=('--help'): 
  #!/usr/bin/env bash
  bin/fetch-from {{parameters}}

# Publish db, assets & files to remote environment
publish-to +parameters=('--help'):
  #!/usr/bin/env bash
  bin/publish-to {{parameters}}

# Import and normalize db in remote environment
remote-db +parameters=('--help'):
  #!/usr/bin/env bash
  bin/remote-db {{parameters}}

# Clear remote cache
cache-clear-remote +parameters=('--help'):
  #!/usr/bin/env bash
  bin/cache-clear {{parameters}}
