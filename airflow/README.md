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

# Agrega el submódulo ETL de Airflow con el formato nombre|URL|rama.
SUBMODULOS=(
        "terrainfo_to_ladm|https://github.com/ceicol/af_terrainfo_to_ladm.git|main"
)

# Descarga o actualiza el submódulo y crea los enlaces hacia el ETL.
bash update_submodules.sh
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

Por defecto en Ubuntu, PostgreSQL escucha solo en localhost. 

## Verifica PostgreSQL en el host Ubuntu

Ejecuta en el host:
``` 
sudo systemctl status postgresql --no-pager
```

Luego:

```
sudo pg_lsclusters
```

## Configura PostgreSQL para escuchar conexiones Docker

Abre el archivo indicado por SHOW config_file;. Generalmente estará en una ruta como:

/etc/postgresql/18/main/postgresql.conf

Edítalo:

```
sudo vim /etc/postgresql/18/main/postgresql.conf
```

Busca:

#listen_addresses = 'localhost'

Para permitir conexiones desde la red Docker puedes usar:

```
listen_addresses = '*'
port = 5432
```

El parámetro listen_addresses determina las interfaces TCP/IP donde PostgreSQL acepta conexiones y requiere reiniciar el servidor para aplicar el cambio.

No significa que cualquier persona podrá conectarse automáticamente: pg_hba.conf, las credenciales y el firewall seguirán controlando el acceso.

## Autoriza solamente la red Docker

Primero averigua la subred de Docker:

```
docker network inspect bridge \
  --format '{{(index .IPAM.Config 0).Subnet}}'
```

```
sudo docker network ls

docker network inspect airflow_default \
  --format '{{(index .IPAM.Config 0).Subnet}}'
```


Podría devolver:

```
172.17.0.0/16
172.18.0.0/16
```

Abre el archivo indicado por:

```
sudo -u postgres psql -d postgres -c "SHOW hba_file;"
```

Generalmente:

```
sudo nano /etc/postgresql/18/main/pg_hba.conf
```

Agrega al final, ajustando la red si Docker mostró otra:

```
host    etl    postgres    172.17.0.0/16    scram-sha-256
host    etl    postgres    172.18.0.0/16    scram-sha-256
```

Para permitir otras bases y usuarios desde esa red:

```
host    all    all    172.17.0.0/16    scram-sha-256
host    all    all    172.18.0.0/16    scram-sha-256
```

La primera opción es más restrictiva y recomendable para tu caso.

Reinicia PostgreSQL:

```
sudo systemctl restart postgresql
```

## Valida la conexión a la base de datos del host desde el contenedor

En el host validamos que postgres este online:

``` 
pg_isready -h 127.0.0.1 -p 5432 -d etl -U postgres
```

Si todo okay, ingresamos al contenedor de airflow y probamos la conexión

```
sudo docker exec -it airflow-airflow-apiserver-1 bash
pg_isready -h host.docker.internal -p 5432 -d etl -U postgres
```


## Despliegues de docker compose

Si deseamos que Airflow soporte QGIS, GRASS y GDAL debemos usar [Dockerfile.airflow-qgis-grass](Dockerfile.airflow-qgis-grass)
Si solo requeremos Airflow con soporte de java 21 pudemos usar [Dockerfile](Dockerfile)


### Reconstruir la imagen de QGIS - Airflow - Java - GDAL - GRASS

```
docker build \
  --no-cache \
  --platform=linux/amd64 \
  -f Dockerfile.airflow-qgis-grass \
  -t airflow-qgis:3.3.0-qgis3.44-grass-java21 \
  .
```

### Validar la nueva imagen

```
docker run --rm \
  --platform=linux/amd64 \
  airflow-qgis:3.3.0-qgis3.44-grass-java21 \
  bash -lc '
    set -eux

    echo "=== GRASS ==="
    grass --version

    echo "=== Plugin ==="
    qgis_process plugins

    echo "=== Algoritmo ==="
    qgis_process help grass:v.clean

    echo "=== Identificador ==="
    qgis_process list | grep -F "grass:v.clean"
  '
```