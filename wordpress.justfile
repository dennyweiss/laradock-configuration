set dotenv-load := false
package-path-prefix := env_var_or_default('COMPOSE_LARADOCK_PACKAGE_PATH', 'vendor/dennyweiss/laradock')
config-package-path-prefix := env_var_or_default('COMPOSE_LARADOCK_CONFIGURATION_PACKAGE_PATH', 'vendor/dennyweiss/laradock-configuration')
config-package-commands-path-prefix := config-package-path-prefix + '/src/commands'
nginx-error-log-path := env_var_or_default('NGINX_ERROR_LOG_PATH', '/usr/local/var/log/nginx/error.log')
nginx-access-log-path := env_var_or_default('NGINX_ACCESS_LOG_PATH', '/usr/local/var/log/nginx/access.log')
php-local-binary := env_var_or_default('PHP_LOCAL_BINARY', 'php')

is-a-mixed-service-stack := env_var_or_default('COMPOSE_SERVICE_STACK_MIXED_WITH_LOCAL', 'false')

# Show available commands
default:
  @just --list

# Show available commands
list:
  @just --list

alias help := default

# docker-compose shorthand
dc +parameters_and_or_services:
  @docker-compose {{parameters_and_or_services}}

# Start one or more services
up +parameters_and_or_services='':
  #!/usr/bin/env bash
  if [[ '{{is-a-mixed-service-stack}}' == 'true' ]] && [[ '{{parameters_and_or_services}}' == 'php-fpm' ]]; then
    brew services restart {{php-local-binary}}
    exit 0
  fi

  if [[ '{{is-a-mixed-service-stack}}' == 'true' ]] && [[ '{{parameters_and_or_services}}' == 'nginx' ]]; then
    brew services restart nginx
    exit 0
  fi

  docker-compose up {{parameters_and_or_services}}

alias start := up

# Start service stack in background
stack-up:
  #!/usr/bin/env bash
  {{config-package-commands-path-prefix}}/docker-compose-stack-up

  if [[ '{{is-a-mixed-service-stack}}' == 'true' ]]; then
    brew services restart {{php-local-binary}}
    brew services restart nginx
  fi

alias stackup := stack-up

# Stop running services
stop +parameters_and_or_services='':
  #!/usr/bin/env bash
  if [[ '{{is-a-mixed-service-stack}}' == 'true' ]] && [[ '{{parameters_and_or_services}}' == 'php-fpm' ]]; then
    brew services stop {{php-local-binary}}
    exit 0
  fi

  if [[ '{{is-a-mixed-service-stack}}' == 'true' ]] && [[ '{{parameters_and_or_services}}' == 'nginx' ]]; then
    brew services stop nginx
    exit 0
  fi

  docker-compose stop {{parameters_and_or_services}}
  if [[ '{{is-a-mixed-service-stack}}' == 'true' ]]; then
    brew services stop {{php-local-binary}}
    brew services stop nginx
  fi

restart:
  #!/usr/bin/env bash
  just stop
  just stackup

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
    php-fpm)
      echo "INFO:  Log nginx errors"
      if [[ '{{is-a-mixed-service-stack}}' == 'true' ]]; then
        echo 'WARN:  Not Implemented'
        echo "ERROR: \$COMPOSE_SERVICE_STACK_MIXED_WITH_LOCAL == '${COMPOSE_SERVICE_STACK_MIXED_WITH_LOCAL}'"
        exit 1
      fi
      docker-compose logs --follow {{service}}
    ;;
    nginx)
      echo "INFO:  Log nginx errors"
      if [[ '{{is-a-mixed-service-stack}}' == 'true' ]]; then
        if [[ ! -f '{{nginx-error-log-path}}' ]]; then
          echo -e "ERROR: Could not find logfile: '{{nginx-error-log-path}}'"
          exit 1
        fi
        tail -f {{nginx-error-log-path}}
        exit 0
      fi
      docker-compose logs --follow {{service}}
    ;;
    nginx-access)
      echo "INFO:  Log nginx access"
      if [[ '{{is-a-mixed-service-stack}}' == 'true' ]]; then
        if [[ ! -f '{{nginx-access-log-path}}' ]]; then
          echo -e "ERROR: Could not find logfile: '{{nginx-access-log-path}}'"
          exit 1
        fi
        tail -f {{nginx-access-log-path}}
        exit 0
      fi
      docker-compose logs --follow {{service}}
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

# Calls composer with parameters inside 'workspace' service
composer +subcommands='':
  #!/usr/bin/env bash
  if [[ '{{is-a-mixed-service-stack}}' == 'true' ]]; then
    composer {{subcommands}}
  else
    docker-compose exec --user="${COMPOSE_USER:-laradock}" workspace composer {{subcommands}}
  fi

# Calls wp-cli with parameters inside 'workspace' service
wp +subcommands='':
  #!/usr/bin/env bash
  if [[ '{{is-a-mixed-service-stack}}' == 'true' ]]; then
    php wp {{subcommands}}
  else
    docker-compose exec --user="${COMPOSE_USER:-laradock}" workspace wp {{subcommands}}
  fi

# Calls npm with parameters inside 'workspace' service defaults to themedir
yarn +subcommands='':
  #!/usr/bin/env bash
  if [[ '{{is-a-mixed-service-stack}}' == 'true' ]]; then
    yarn {{subcommands}}
  else
    docker-compose exec --user="${COMPOSE_USER:-laradock}" workspace yarn {{subcommands}}
  fi

# Opens bash console inside workspace container
bash +subcommands='':
  #!/usr/bin/env bash
  if [[ '{{is-a-mixed-service-stack}}' == 'true' ]]; then
    echo "ERROR: \$COMPOSE_SERVICE_STACK_MIXED_WITH_LOCAL == '${COMPOSE_SERVICE_STACK_MIXED_WITH_LOCAL}'"
    exit 1
  fi

  docker-compose exec --user="${COMPOSE_USER:-laradock}" workspace bash {{subcommands}}

# Imports SQL DB from file and applies correct 'WP_HOME' or exports SQL dump to file
db action filepath='':
  @'{{config-package-commands-path-prefix}}/docker-wordpress-db' {{action}} {{filepath}}

# Calls actions [start|stop|status] on xdebug
xdebug action='help':
  #!/usr/bin/env bash
  if [[ '{{is-a-mixed-service-stack}}' == 'true' ]]; then
    echo "ERROR: \$COMPOSE_SERVICE_STACK_MIXED_WITH_LOCAL == '${COMPOSE_SERVICE_STACK_MIXED_WITH_LOCAL}'"
    exit 1
  fi
  '{{config-package-path-prefix}}/src/commands/docker-exec-xdebug' {{action}}

# Fetch db, assets & files from remote environment
fetch-from +parameters=('--help'):
  @'{{config-package-path-prefix}}/src/fetch-from' {{parameters}}

# Publish db, assets & files to remote environment
publish-to +parameters=('--help'):
  @'{{config-package-path-prefix}}/src/publish-to' {{parameters}}

# Import and normalize db in remote environment
remote-db +parameters=('--help'):
  @'{{config-package-path-prefix}}/src/remote-db' {{parameters}}

# Clear remote cache
cache-clear-remote +parameters=('--help'):
  @'{{config-package-path-prefix}}/src/cache-clear' {{parameters}}
