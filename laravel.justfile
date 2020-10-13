# make docker-path overridable in case of supporting addtional project roots
docker-path :=  env_var_or_default('DC_PATH', '.docker')
nginx-error-log-path := env_var_or_default('NGINX_ERROR_LOG_PATH', '/usr/local/var/log/nginx/error.log')
nginx-access-log-path := env_var_or_default('NGINX_ACCESS_LOG_PATH', '/usr/local/var/log/nginx/access.log')
move-to-docker-dir := 'cd ' + docker-path + '&& '

indent := "  "
indent2x := indent + indent
task-prefix := '>>' + indent
warn-prefix := indent2x + 'WARN: '

## @info new variables
package-path-prefix := 'vendor/dennyweiss/laradock' # @todo use '$COMPOSE_LARADOCK_PACKAGE_PATH'
config-package-path-prefix := 'vendor/dennyweiss/laradock-configuration' # @todo use '$COMPOSE_LARADOCK_CONFIGURATION_PACKAGE_PATH'
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
  #!/usr/bin/env bash
  if [[ '{{parameters_and_or_services}}' == 'php' ]]; then
    brew services run php
    exit 0
  fi

  if [[ '{{parameters_and_or_services}}' == 'nginx' ]]; then
    brew services run nginx
    exit 0
  fi

  docker-compose up {{parameters_and_or_services}}

alias start := up

# Start service stack in background
stack-up:
  #!/usr/bin/env bash
  {{config-package-commands-path-prefix}}/docker-compose-stack-up
  brew services run php
  brew services run nginx

alias stackup := stack-up

# Stop running services
stop +parameters_and_or_services='':
  #!/usr/bin/env bash
  if [[ '{{parameters_and_or_services}}' == 'php' ]]; then
    brew services stop php
    exit 0
  fi

  if [[ '{{parameters_and_or_services}}' == 'nginx' ]]; then
    brew services stop nginx
    exit 0
  fi

  docker-compose stop {{parameters_and_or_services}}
  brew services stop php
  brew services stop nginx

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
  #!/usr/bin/env bash
  service='{{service}}'

  case "${service}" in
    php)
      echo 'WARN:  Not Implemented'
    ;;
    nginx)
      echo "INFO:  Log nginx errors"
      if [[ ! -f '{{nginx-error-log-path}}' ]]; then
        echo -e "ERROR: Could not find logfile: '{{nginx-error-log-path}}'"
        exit 1
      fi
      tail -f {{nginx-error-log-path}}
    ;;
    nginx-access)
      echo "INFO:  Log nginx access"
      if [[ ! -f '{{nginx-access-log-path}}' ]]; then
        echo -e "ERROR: Could not find logfile: '{{nginx-access-log-path}}'"
        exit 1
      fi
      tail -f {{nginx-access-log-path}}
    ;;
    *)
      docker-compose logs --follow {{service}}
    ;;
  esac

# Fetch container images from registries
images-prefetch +images:
  @docker-compose pull {{images}}

# Log into user defined 'USER_DR_URL' docker registry
registry action:
  @'{{config-package-commands-path-prefix}}/docker-registry' {{action}}

# Encrypt or decrypt file
vault action file:
  @'{{config-package-commands-path-prefix}}/vault' {{action}} {{file}}
