
from airflow.providers.postgres.operators.postgres import PostgresOperator

def task_validar_conexion(postgres_conn_id: str):
    return PostgresOperator(
        task_id="validar_conexion_postgres",
        postgres_conn_id=postgres_conn_id,
        sql="SELECT 1;",
    )
