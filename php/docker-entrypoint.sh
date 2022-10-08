#!/usr/bin/env bash

set -e

printf "\n\033[34m--- [$CONTAINER_ROLE] ENTRYPOINT APP --- \033[0m\n"

# Convert to UPPERCASE
CONTAINER_ROLE=${CONTAINER_ROLE^^}

if [ -z "$APP_ENV" ]; then
    printf "\n\033[31m[$CONTAINER_ROLE] A \$APP_ENV environment is required to run this container!\033[0m\n"
    exit 1
fi

if [ -z "$APP_KEY" ]; then
    printf "\n\033[31m[$CONTAINER_ROLE] A \$APP_KEY environment is required to run this container!\033[0m\n"
    exit 1
fi

shopt -s dotglob
sudo chown -R ${USER_NAME}:${USER_NAME} \
        /home/${USER_NAME} \
        /usr/local/var/run \
        /var/run /var/run/ \
        /var/log \
        /tmp/php \
        $LOG_PATH
shopt -u dotglob

sudo find /usr/local/etc ! -name "php.ini" | xargs -I {} chown ${USER_NAME}:${USER_NAME} {}

configure_php_ini() {
    sed -i \
        -e "s/memory_limit.*$/memory_limit = ${PHP_MEMORY_LIMIT:-128M}/g" \
        -e "s/max_execution_time.*$/max_execution_time = ${PHP_MAX_EXECUTION_TIME:-30}/g" \
        -e "s/max_input_time.*$/max_input_time = ${PHP_MAX_INPUT_TIME:-30}/g" \
        -e "s/post_max_size.*$/post_max_size = ${PHP_POST_MAX_SIZE:-8M}/g" \
        -e "s/upload_max_filesize.*$/upload_max_filesize = ${PHP_UPLOAD_MAX_FILESIZE:-2M}/g" \
    \
    $PHP_INI_DIR/php.ini
}

install_composer_dependencies() {
    if [ ! -d "vendor" ] && [ -f "composer.json" ]; then
        printf "\n\033[33mComposer vendor folder was not installed. Running >_ composer install --prefer-dist --no-interaction --optimize-autoloader --ansi\033[0m\n\n"

        composer install --prefer-dist --no-interaction --optimize-autoloader --ignore-platform-reqs --ansi

        printf "\n\033[33mcomposer run-script post-root-package-install\033[0m\n\n"

        composer run-script post-root-package-install

        printf "\n\033[33mcomposer run-script post-autoload-dump\033[0m\n\n"

        composer run-script post-autoload-dump
    fi
}

# $> {view:clear} && {cache:clear} && {route:clear} && {config:clear} && {clear-compiled}
# @see https://github.com/laravel/framework/blob/9.x/src/Illuminate/Foundation/Console/OptimizeClearCommand.php
if [[ -d "vendor" && ${FORCE_CLEAR:-false} == true ]]; then
    printf "\n\033[33mLaravel - artisan view:clear + route:clear + config:clear + clear-compiled\033[0m\n\n"

    php artisan event:clear || true
    php artisan view:clear
    php artisan route:clear
    php artisan config:clear
    php artisan clear-compiled
fi

if [[ -d "vendor" && ${CACHE_CLEAR:-false} == true ]]; then
    printf "\n\033[33mLaravel - artisan cache:clear\033[0m\n\n"

    php artisan cache:clear 2>/dev/null || true
fi

if [[ -d "vendor" && ${FORCE_OPTIMIZE:-false} == true ]]; then
    printf "\n\033[33mLaravel Cache Optimization - artisan config:cache + route:cache + view:cache\033[0m\n\n"

    # $> {config:cache} && {route:cache}
    # @see https://github.com/laravel/framework/blob/9.x/src/Illuminate/Foundation/Console/OptimizeCommand.php
    php artisan optimize || true
    php artisan view:cache || true
fi

if [[ -d "vendor" && ${FORCE_MIGRATE:-false} == true ]]; then
    printf "\n\033[33mLaravel - artisan migrate --force\033[0m\n\n"

    php artisan migrate --force || true
fi

if [[ ${FORCE_STORAGE_LINK:-false} == true ]]; then
    printf "\n\033[33mLaravel - artisan storage:link\033[0m\n\n"

    rm -rf ${REMOTE_SRC}/public/storage || true
    php artisan storage:link || true
fi

if [[ ${XDEBUG_ENABLED:-false} == false ]]; then
    rm -f ${PHP_LOG_PATH}/php-xdebug.log >/dev/null 2>&1 || true

    rm -f ${PHP_INI_SCAN_DIR}/docker-php-ext-xdebug.ini >/dev/null 2>&1 || true
    rm -f ${PHP_INI_SCAN_DIR}/xdebug.ini >/dev/null 2>&1 || true
fi

if [[ ${PCOV_ENABLED:-false} == false ]]; then
    rm -f ${PHP_INI_SCAN_DIR}/docker-php-ext-pcov.ini >/dev/null 2>&1 || true
    rm -f ${PHP_INI_SCAN_DIR}/pcov.ini >/dev/null 2>&1 || true
fi

if [[ ${OPCACHE_ENABLED:-true} == false ]]; then
    rm -f ${PHP_INI_SCAN_DIR}/opcache.ini >/dev/null 2>&1 || true
    rm -f ${PHP_INI_SCAN_DIR}/docker-php-ext-opcache.ini >/dev/null 2>&1 || true
fi

if [ "$APP_ENV" = "production" ]; then
    configure_php_ini
fi

install_composer_dependencies

echo
php -v
echo
php --ini

if [ "$CONTAINER_ROLE" = "APP" ]; then

    if [[ ${WITH_OCTANE:-false} == true ]]; then
        printf "\033[34m[$CONTAINER_ROLE] Running with Laravel Octane ...\033[0m\n"

        exec /usr/local/bin/php -d variables_order=EGPCS artisan octane:start --server=swoole --max-requests=100000 --host=0.0.0.0 --port=8000
    fi

    printf "\033[34m[$CONTAINER_ROLE] Running with Laravel Serve ...\033[0m\n"

    exec /usr/local/bin/php -d variables_order=GPCS artisan serve --host=0.0.0.0 --port=8000

elif [ "$CONTAINER_ROLE" = "QUEUE" ]; then
    printf "\n\033[34m[$CONTAINER_ROLE] Running the [QUEUE-WORKER] Service ...\033[0m\n"

    exec php artisan queue:work \
                ${QUEUE_CONNECTION:-redis} \
                --env="$APP_ENV" \
                --max-time=3600 \
                --max-jobs=500 \
                --queue=important,emails,high,${REDIS_QUEUE:-default},low \
                --memory=${QUEUE_MEMORY:-64} \
                --sleep=${QUEUE_SLEEP:-10} \
                --tries=${QUEUE_TRIES:-3} \
                --backoff=${QUEUE_BACKOFF:-3} \
                --timeout=${QUEUE_TIMEOUT:-60}

elif [ "$CONTAINER_ROLE" = "SCHEDULER" ]; then
    printf "\n\033[34m[$CONTAINER_ROLE] Starting [CRON] Service ...\033[0m\n\n"

    exec php artisan schedule:work
fi

exec "$@"
