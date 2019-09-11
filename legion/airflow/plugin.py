from airflow.plugins_manager import AirflowPlugin

from legion.airflow.deployment import DeploymentOperator, DeploymentSensor
from legion.airflow.edi import LegionHook
from legion.airflow.model import ModelPredictRequestOperator, ModelInfoRequestOperator
from legion.airflow.packaging import PackagingOperator, PackagingSensor
from legion.airflow.training import TrainingOperator, TrainingSensor


class LegionPlugin(AirflowPlugin):
    name = 'legion'
    operators = [TrainingOperator, DeploymentOperator, PackagingOperator, ModelPredictRequestOperator,
                 ModelInfoRequestOperator]
    hooks = [LegionHook]
    sensors = [TrainingSensor, DeploymentSensor, PackagingSensor]
