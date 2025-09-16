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

```

4. Registra tu submodulo


```shell
vi update_submodules.sh

# add submodule etl AirFlow
SUBMODULES=(
        "https://github.com/ceicol/af_terrainfo_to_ladm.git terrainfo_to_ladm"
)

sh update_submodules.sh
```


5. Desplegamos airflow
```shell
cd airflow
docker compose up -d
```

## Usar host.docker.internal en linux

Cuando desees utilizar tu base de datos de tu host en postgres a través de host.docker.internal debes realizar la siguiente configuración:

1. Primero mira la IP del puente en el host:

```shell
ip addr show docker0 | grep 'inet '
```

2. Habilitar conexiones externas en postgres

*Importante*: habilitar que PostgreSQL escuche conexiones “externas”

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

## Configuraciones adicionales

Para utilizar DockerOperator debemos dar los permisos requeridos en linux:

```shell
echo "DOCKER_SOCK_GROUP=$(stat -c '%g' /var/run/docker.sock)" >> .env
docker compose -f compose.dev.yaml exec airflow-scheduler docker ps
```


## Despliegues de docker compose

[compose con soporte para DockerOperator](compose.geodev.yaml)
[Compose sin soporte para DockerOperator](compose.dev.yaml)