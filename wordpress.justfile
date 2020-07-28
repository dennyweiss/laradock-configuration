# make docker-path overridable in case of supporting addtional project roots
docker-path :=  env_var_or_default('DC_PATH', '.docker')
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

# Calls npm with parameters inside 'workspace' service defaults to themedir
yarn +subcommands='':
  @'{{config-package-commands-path-prefix}}/docker-compose-exec-yarn' {{subcommands}}

# Opens bash console inside workspace container
bash +subcommands='':
  @docker-compose exec --user="${COMPOSE_USER:-laradock}" workspace bash {{subcommands}}

# Imports SQL DB from file and applies correct 'WP_HOME' or exports SQL dump to file
db action filepath='':
  @'{{config-package-commands-path-prefix}}/docker-wordpress-db' {{action}} {{filepath}}

# Calls actions [start|stop|status] on xdebug
xdebug action='status':
  @'{{package-path-prefix}}/php-fpm/xdebug' {{action}}

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
