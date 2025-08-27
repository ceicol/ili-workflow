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
