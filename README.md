# Simple Docker Setup For Laravel

> Simple setup Docker, for Laravel applications.

## 🐳 Containers that can run:

- **Laravel APP** - `php artisan serve`
- **Laravel Queue** - `php artisan queue:work`
- **Laravel Schedule** - `php artisan schedule:work`
- **MySQL**
- **Redis**

## 🐳 Docker images included:

- **PHP** `8.1-cli-alpine`
- **MySQL** `8.0`
- **Redis** `7.0-alpine`

## Clone the project

*Minimum Laravel version for this project is:* **V8**

```
$ git clone https://github.com/allysonsilva/simple-docker-laravel docker
```

## 🔧 Configuration

- **`docker` must be inside *Laravel application_***
    - The folder name is configurable via the `LOCAL_DOCKER_FOLDER` variable of the `.env` environment file

**The organization of the folders should serve as a reference for organizing this repository Docker + Laravel Application:**

```
.
└── /var/www/app
                ├── app
                ├── bootstrap
                ├── config
                ├── database
                ├── docker <-------
                ├── lang
                └── ...
```

- **Execute command `make -f docker/Makefile docker/config-env`**
- ***Edit the variable `COMPOSE_PROJECT_NAME`, to a value that matches the application***
  - Open the `.envrc` file and change the value of the prefixed variables from `app_` to the value of the `COMPOSE_PROJECT_NAME` variable, so, for example:
    - If you set the value of the `COMPOSE_PROJECT_NAME` variable to `myapp`, change the value of the `database_container` variable in the `.envrc` file to `myapp_database` and the value of the `redis_container` variable to `myapp_redis`.

## 🐳 Build the image of the Laravel/APP

It is necessary to build the image that will be used by the application, queue and scheduling containers.

1. Copy the `.dockerignore` file to a higher folder level with the command `cp docker/.dockerignore .`
2. Open the `.env` in `docker/.env` file and edit the variables if necessary `APP_IMAGE`, `APP_LOCAL_FOLDER`
    - `APP_IMAGE`: **Docker image tag** that will be used in its creation through the `docker/build/app` command and also **used in the execution of PHP/Laravel containers**
    - `APP_LOCAL_FOLDER`: Name of the folder where the Laravel application is located. Can be relative path (default) or absolute path to application folder

*Use the command to build the image*: `make -f docker/Makefile docker/build/app`

## 🚀 Up Containers

Use the command below to **up** the *application containers*, *MySQL* and *Redis*:

```bash
make -f docker/Makefile docker/up
```

If you want to *recreate* or *create* containers individually, use the commands:

- *MySQL*:
  - `make -f docker/Makefile docker/database/up`
- *Redis*:
  - `make -f docker/Makefile docker/redis/up`
- *APP*:
  - `make -f docker/Makefile docker/app/up`
- *Queue*:
  - `make -f docker/Makefile docker/queue/up`
- *Scheduler*:
  - `make -f docker/Makefile docker/scheduler/up`

Use the `up_options` argument in the above commands to customize the arguments that will be passed in the `up` command of `docker-compose`. As follows: `make -f docker/Makefile docker/app/up up_options="--force-recreate --no-deps"`
    - To see the list of options use the command: `docker-compose up --help`

## 📝  Changelog

Please see [CHANGELOG](CHANGELOG.md) for more information about the changes on this package.

## 🤝  Contributing

Please see [CONTRIBUTING](CONTRIBUTING.md) for details.

## License

The MIT License (MIT). Please see [License File](LICENSE.md) for more information.
