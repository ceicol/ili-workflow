# ili-workflow

Orquestador ETL en Apache Airflow para gestionar y transformar datos definidos en INTERLIS.

## Desarrolladores

1. Clona el repositorio en tu máquina local:

    ```shell
    git clone https://github.com/ceicol/ili-workflow.git
    ```
2. Crea tu archivo .env

3. Configura un entorno virtual e instala las dependencias requeridas:

    ```shell
    cd ili-workflow/

    # Se instala librería de ili2db
    sh scripts/download_dependencies.sh

    cd airflow
    docker compose up -d
    ```


## Conexión BD

Primero mira la IP del puente en el host:

```shell
ip addr show docker0 | grep 'inet '
```

Importante: habilitar que PostgreSQL escuche conexiones “externas”

Por defecto en Ubuntu, PostgreSQL escucha solo en localhost. Necesitas permitir conexiones desde el contenedor:

postgresql.conf (/etc/postgresql/<versión>/main/postgresql.conf):

```shell
listen_addresses = '0.0.0.0'
port = 5432
```

pg_hba.conf (/etc/postgresql/<versión>/main/pg_hba.conf):
```shell
# docker brigde por defecto
host    all             all             172.17.0.0/16           md5
host    all             all             172.18.0.0/16           md5
```

Recargar PostgreSQL:

```shell
sudo systemctl reload postgresql
```

