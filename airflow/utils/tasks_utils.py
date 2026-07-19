
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

def task_validar_conexion(postgres_conn_id: str):
    return SQLExecuteQueryOperator(
        task_id="validar_conexion_postgres",
        conn_id=postgres_conn_id,
        sql="SELECT 1;",
    )
