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

defaultServices := 'nginx mysql workspace'
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
up +parameters_and_or_services:
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

# @info source files from "$(dirname "${0}")/../library/ddd-lib"
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

# Calls composer with parameters inside 'workspace' service
composer +subcommands='':
  #!/usr/bin/env bash
  echo ''
  echo "{{task-prefix}}composer inside workspace"

  subcommands="{{subcommands}}"

  if [[ "{{debug-mode}}" == 'true' ]]; then
    echo ''
    echo "{{indent2x}}subcommands:"
    echo "{{indent2x}}  '${subcommands}'"
    echo ''
  fi

  {{dry-run-script}}
  {{move-to-docker-dir}} docker-compose {{docker-compose-project-name}} exec {{default-user}} workspace composer ${subcommands}

# Calls wp-cli with parameters inside 'workspace' service
wp +parameters='':
  #!/usr/bin/env bash
  echo ''
  echo "{{task-prefix}}wp-cli inside workspace"

  parameters="{{parameters}}"

  if [[ "{{debug-mode}}" == 'true' ]]; then
    echo ''
    echo "{{indent2x}}parameters:"
    echo "{{indent2x}}  '${parameters}'"
    echo ''
  fi

  {{dry-run-script}}
  {{move-to-docker-dir}} docker-compose {{docker-compose-project-name}} exec {{default-user}} workspace wp ${parameters}

# Calls npm with parameters inside 'workspace' service defaults to themedir
npm +subcommands='':
  #!/usr/bin/env bash
  echo ''

  projectroot="{{root}}"
  subcommands="{{subcommands}}"
  themedir="{{themedir}}"

  if [[ "${projectroot}" == 'true' ]]; then
    echo "{{task-prefix}}npm inside project root"
  else
    echo "{{task-prefix}}npm inside theme '${themedir}'"
  fi

  if [[ "{{debug-mode}}" == 'true' ]]; then
    echo ''
    echo "{{indent2x}}projectroot:    '${projectroot}'"
    echo "{{indent2x}}themedir:       '${themedir}'"
    echo "{{indent2x}}subcommands:"
    echo "{{indent2x}}  '${subcommands}'"
    echo ''
  fi

  {{dry-run-script}}
  if [[ "${projectroot}" == 'true' ]]; then
    {{move-to-docker-dir}} docker-compose {{docker-compose-project-name}} exec {{default-user}} workspace \
      npm ${subcommands}
  else
    {{move-to-docker-dir}} docker-compose {{docker-compose-project-name}} exec {{default-user}} workspace \
      npm --prefix "${themedir}" ${subcommands}
  fi

# Opens bash console inside workspace container
bash:
  #!/usr/bin/env bash
  echo ''
  {{move-to-docker-dir}} docker-compose {{docker-compose-project-name}} exec {{default-user}} workspace bash

# Fetches project dependencies (composer for php and npm for theme packages)
fetch:
  #!/usr/bin/env bash
  echo ''
  echo "{{task-prefix}}Fetch dependencies"
  themedir="{{themedir}}"

  if [[ "{{debug-mode}}" == 'true' ]]; then
    echo ''
    echo "{{indent2x}}themedir:       '${themedir}'"
    echo ''
  fi

  just composer install -o --no-dev
  just npm install

# Builds frontend assets for specified environment
frontend-build environment=current_environment:
  #!/usr/bin/env bash
  
  environment="{{environment}}"
  normalizedenvironment=''
  if [[ "${environemt}" == 'staging' ]]; then
    normalizedenvironment='development'
  else 
    normalizedenvironment="${environment}"
  fi

  if [[ "{{debug-mode}}" == 'true' ]]; then
    echo ''
    echo "{{indent2x}}environment:            '${environment}'"
    echo "{{indent2x}}normalizedenvironment:  '${normalizedenvironment}'"
    echo "{{indent2x}}WP_ENV:                 '${WP_ENV}'"
    echo ''
  fi

  if [[ "${normalizedenvironment}" == 'development' ]]; then
    just npm run development
    exit 0
  fi

  if [[ "${normalizedenvironment}" == 'production' ]]; then
    just npm run production
    exit 0
  fi

  echo ''
  echo "{{warn-prefix}}Environment '${normalizedenvironment}' is not supported"
  echo ''
  exit 1

# Builds watches frontend files for changes and builds assets
frontend-watch polling='false':
  #!/usr/bin/env bash

  echo ''
  usepolling="{{polling}}"

  pollstring=''
  if [[ "${usepolling}" == 'true' ]]; then
    pollstring='(with polling)'
  fi

  if [[ "{{debug-mode}}" == 'true' ]]; then
    echo ''
    echo "{{indent2x}}usepolling:       '${usepolling}'"
    echo "{{indent2x}}pollstring:       '${pollstring}'"
    echo ''
  fi

  echo "{{task-prefix}}Run npm watch ${pollstring}"

  if [[ "${usepolling}" == 'true' ]]; then
    just npm run watch-poll
  else
    just npm run watch
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

# configures starter for project name and app type
configure project-name app-type='wordpress' xdebug='false':
  #!/usr/bin/env bash

  just _print_title 'Configure local development environment'

  environment="{{current_environment}}"
  if [[ "${environment}" != 'development' ]]; then
    just _print_error "Environment '${environment}' not supported"
    exit 1
  fi

  project_name="{{project-name}}"
  project_placeholder='{{projectNamePlaceholder}}'

  project_env_template=".env.example"
  project_env_target=".env"

  docker_path="{{docker-path}}"
  app_type="{{app-type}}"
  xdebug="{{xdebug}}"

  docker_env_source="${docker_path}/.environments/env.${app_type}"
  if [[ "${xdebug}" == 'true' ]]; then
    docker_env_source="${docker_env_source}.xdebug"
  fi
  docker_env_target="${docker_path}/.env"

  source_justfile="${docker_path}/.justfile/${app_type}.justfile"
  target_justfile="justfile"

  source_readme="${docker_path}/.justfile/${app_type}.md"
  target_readme="README-justfile.md"

  if [[ "{{debug-mode}}" == 'true' ]]; then
      echo ''
      echo "{{indent2x}}project_name:           '${project_name}'"
      echo "{{indent2x}}project_placeholder:    '${project_placeholder}'"
      echo "{{indent2x}}project_env_template:   '${project_env_template}'"
      echo "{{indent2x}}project_env_target:            '${project_env_target}'"
      echo ''
      echo "{{indent2x}}docker_path:            '${docker_path}'"
      echo "{{indent2x}}app_type:               '${app_type}'"
      echo "{{indent2x}}xdebug:                 '${xdebug}'"
      echo ''
      echo "{{indent2x}}docker_env_source:      '${docker_env_source}'"
      echo "{{indent2x}}docker_env_source:      '${docker_env_target}'"
      echo ''
      echo "{{indent2x}}source_justfile:        '${source_justfile}'"
      echo "{{indent2x}}target_justfile:        '${target_justfile}'"
      echo ''
      echo "{{indent2x}}source_readme:          '${source_readme}'"
      echo "{{indent2x}}target_readme:          '${target_readme}'"
      echo ''
  fi

  {{dry-run-script}}

  just link-files "${source_justfile}" "${target_justfile}" 'Link justfile with main project'
  just link-files "${source_readme}" "${target_readme}" 'Link readme for justfile with main project'

  just render-template "${project_env_template}" "${project_env_target}" "${project_name}" "Create main project .env"
  just render-template "${docker_env_source}" "${docker_env_target}" "${project_name}" "Create main project .env"

  just _print_ok_end "project configured"

# links source file to target
link-files source target title='Link files':
  #!/usr/bin/env bash

  source_filepath="{{source}}"
  target_filepath="{{target}}"

  just _print_task_title '{{title}}'
  just _print_task_description "source_filepath: '${source_filepath}'"
  just _print_task_description "target_filepath: '${target_filepath}'"

  if [[ ! -f "${source_filepath}" ]]; then
    just _print_error 'source file '${source_filepath}' missing'
    exit 1
  fi

  if [[ -f "${target_filepath}" ]]; then
    just _print_error "target already exist"
    just create-backup "${target_filepath}"
    rm "${target_filepath}"
    if [[ "${?}" != "0" ]]; then
      just _print_error 'removing existing target failed'
      exit 1
    fi
    echo ''
  fi

  ln -s "${source_filepath}" "${target_filepath}" 2>/dev/null
  if [[ "${?}" != "0" ]]; then
    just _print_error 'linking failed'
    exit 1
  fi

  just _print_progress_result "linked '$(ls -l "${target_filepath}" | awk '{ print $9, $10, $11 }')'"

# renders a configuration template
render-template source target projectName title='Render template to file':
  #!/usr/bin/env bash

  source_filepath="{{source}}"
  target_filepath="{{target}}"
  project_name="{{projectName}}"
  project_placeholder='{{projectNamePlaceholder}}'

  just _print_task_title "{{title}}"
  just _print_task_description "project_name:       '${project_name}'"
  just _print_task_description "source_filepath:    '${source_filepath}'"
  just _print_task_description "target_filepath:    '${target_filepath}'"

  if [[ ! -f "${source_filepath}" ]]; then
    just _print_error "source file '${source_filepath}' missing"
    exit 1
  fi

  if [[ -f "${target_filepath}" ]]; then
    just _print_error "target already exist"
    just create-backup "${target_filepath}"
    rm "${target_filepath}"
    if [[ "${?}" != "0" ]]; then
      just _print_error 'removing existing target failed'
      exit 1
    fi
    echo ''
  fi

  sed "s|$project_placeholder|$project_name|" "${source_filepath}" > "${target_filepath}" 2>/dev/null

  if [[ "${?}" != "0" ]]; then
    just _print_error "'${target_filepath}' creation failed"
    exit 1
  fi

  just _print_progress_result "created '${target_filepath}'"

# creates a datetime-suffixed backup file
create-backup filepath:
  #!/usr/bin/env bash

  source_filepath="{{filepath}}"
  target_filepath="${source_filepath}-$(date "+%Y%m%d-%H%M%S")"

  just _print_task_title "Create backup from '${source_filepath}'"
  just _print_task_description "source_filepath:  '${source_filepath}'"
  just _print_task_description "target_filepath:  '${target_filepath}'"

  if [[ ! -f "${source_filepath}" ]]; then
    just _print_error "source file '${source_filepath}' missing"
    exit 1
  fi

  cp "${source_filepath}" "${target_filepath}"
  if [[ "${?}" != "0" ]]; then
    just _print_error "backup failed"
    exit 1
  fi

  just _print_progress_result "created '${target_filepath}'"


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
