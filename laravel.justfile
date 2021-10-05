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

# Create ACR service priciple for roles [owner,acrpull,acrpush]
acr-create-service-principle acr_name='eteamacr.azurecr.io' acr_role='' service_principle_name='':
  #!/usr/bin/env bash
  ACR_NAME='{{acr_name}}'
  ACR_ROLE='{{acr_role}}'
  SERVICE_PRINCIPAL_NAME='{{service_principle_name}}'

  if ! which az &>/dev/null; then
    echo "ERROR: 'az' missing but required"
    exit 1
  fi

  if [[ "${DEBUG:-false}" == 'true' ]]; then
    echo -e "\$ACR_NAME:                '${ACR_NAME}'"
    echo -e "\$SERVICE_PRINCIPAL_NAME:  '${SERVICE_PRINCIPAL_NAME}'"
    echo -e "\$ACR_ROLE:                '${ACR_ROLE}'"
  fi

  # Obtain the full registry ID for subsequent command args
  ACR_REGISTRY_ID=$(az acr show --name $ACR_NAME --query id --output tsv)

  # Create the service principal with rights scoped to the registry.
  # Default permissions are for docker pull access. Modify the '--role'
  # argument value as desired:
  # acrpull:     pull only
  # acrpush:     push and pull
  # owner:       push, pull, and assign roles
  SP_PASSWD=$(az ad sp create-for-rbac --name http://$SERVICE_PRINCIPAL_NAME --scopes $ACR_REGISTRY_ID --role acrpull --query password --output tsv)
  SP_APP_ID=$(az ad sp show --id http://$SERVICE_PRINCIPAL_NAME --query appId --output tsv)

  echo -e "\$SERVICE_PRINCIPAL_NAME   = '${SERVICE_PRINCIPAL_NAME}'"
  echo -e "\$USER_DR_URL              = '${ACR_NAME}'"
  echo -e "\$USER_DR_SP_APP_ID        = '${SP_APP_ID}'"
  echo -e "\$USER_DR_SP_APP_PASSWORD  = '${SP_PASSWD}'"

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

# Calls composer with parameters inside 'workspace' service
artisan +subcommands='':
  #!/usr/bin/env bash
  if [[ '{{is-a-mixed-service-stack}}' == 'true' ]]; then
    php artisan {{subcommands}}
  else
    docker-compose exec --user="${COMPOSE_USER:-laradock}" workspace php artisan {{subcommands}}
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

# Opens bash console inside workspace container
phpunit +subcommands='':
  #!/usr/bin/env bash
  if [[ '{{is-a-mixed-service-stack}}' == 'true' ]]; then
    php bin/phpunit
  else
    docker-compose exec --user="${COMPOSE_USER:-laradock}" workspace php bin/phpunit {{subcommands}}
  fi


# Calls actions [start|stop|status] on xdebug
xdebug action='help':
  #!/usr/bin/env bash
  if [[ '{{is-a-mixed-service-stack}}' == 'true' ]]; then
    echo "ERROR: \$COMPOSE_SERVICE_STACK_MIXED_WITH_LOCAL == '${COMPOSE_SERVICE_STACK_MIXED_WITH_LOCAL}'"
    exit 1
  fi
  '{{config-package-path-prefix}}/src/commands/docker-exec-xdebug' {{action}}

# push docker image
image-push image='':
  #!/usr/bin/env bash
  image_name='{{image}}'

  if [[ "${image_name}" != '--all' ]]; then
    docker push ${image_name}
  else
    for image in $(just image-list); do
      [[ "${image}" =~ ^docker:.*-dind$ ]] && continue;
      just image-push "${image}"
    done
  fi

image-list:
  #!/usr/bin/env bash
  images=( "$(docker-compose config | grep image)" )
  for image in ${images[@]}; do
    if [[ "${image}" != 'image:' ]]; then
      echo "${image}"
    fi
  done

code-style type='all':
  #!/usr/bin/env bash

  apply_php_code_style() {
    echo
    echo "INFO:  Apply php cs fixer"
    bin/php-cs-fixer fix
  }

  apply_frontend_code_styles() {
    echo
    echo "INFO:  Apply prettier"
    node_modules/.bin/prettier --ignore-path=.eslintignore  --loglevel=log --write --list-different .
  }

  if [[ ! -L 'bin/php-cs-fixer' ]]; then
    echo -e "ERROR: PHP CS Fixer missing but required"
    exit 1
  fi

  if [[ ! -L 'node_modules/.bin/prettier' ]]; then
    echo -e "ERROR: Prettier missing but required"
    exit 1
  fi

  case '{{type}}' in
    php)
        apply_php_code_style
        ;;
    frontend|js)
        apply_frontend_code_styles
        ;;
    all)
        apply_php_code_style
        apply_frontend_code_styles
        ;;
    *)
     echo -e "ERROR: '{{type}}' not supported, use [php|frontend|js|all]"
     exit 1
     ;;
  esac

