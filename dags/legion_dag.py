from airflow.operators.bash_operator import BashOperator
from airflow import DAG
from datetime import datetime, timedelta

from legion_airflow import TrainingOperator
from legion_airflow.legion_plugin import TrainingSensor

debugToken = 'debugToken'

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2019, 9, 3),
    'email': ['jasonnerothin@gmail.com'],
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=1),
    'oauth2_token': debugToken,
    'end_date': datetime(2099, 12, 31)
    # 'queue': 'bash_queue',
    # 'pool': 'backfill',
    # 'priority_weight': 10,
}

dag = DAG(
    'Legion Training DAG',
    default_args=default_args,
    schedule_interval=timedelta(days=1)
)

with dag:
    hello = BashOperator(task_id='Hello',
                         bash_command='echo "Hello, Squirreled!"',
                         default_args=default_args)

    train = TrainingOperator(task_id='Train',
                             name='UniqueTrainingName',
                             model_name='jason',
                             model_version='22',
                             action='create')

    waitForTrain = TrainingSensor(task_id='WaitForTrain',
                                  name='UniqueTrainingName',
                                  model_name='jason',
                                  model_version='22')

    goodbye = BashOperator(task_id='Goodbye',
                           bash_command='echo "Goodbye, cruel world!"',
                           default_args=default_args)

hello >> train >> waitForTrain >> goodbye
