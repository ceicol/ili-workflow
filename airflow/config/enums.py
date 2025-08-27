from enum import Enum

class Ili2dbJarPath(Enum):
    LEGACY = "/opt/airflow/libs/iliwrapper/bin/ili2pg-4.4.3/ili2pg-4.4.3.jar"
    LATEST = "/opt/airflow/libs/iliwrapper/bin/ili2pg-5.3.1/ili2pg-5.3.1.jar"