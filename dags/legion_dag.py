from datetime import datetime

from airflow import DAG
from legion.sdk.models import ModelTraining, ModelTrainingSpec, ModelIdentity, ResourceRequirements, ResourceList, \
    ModelPackaging, ModelPackagingSpec, Target, ModelDeployment, ModelDeploymentSpec

from legion.airflow.deployment import DeploymentOperator, DeploymentSensor
from legion.airflow.model import ModelPredictRequestOperator, ModelInfoRequestOperator
from legion.airflow.packaging import PackagingOperator, PackagingSensor
from legion.airflow.training import TrainingOperator, TrainingSensor

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2019, 9, 3),
    'email_on_failure': False,
    'email_on_retry': False,
    'end_date': datetime(2099, 12, 31)
}

edi_connection_id = "legion_edi"
model_connection_id = "legion_model"

training_id = "airlfow-wine"
training = ModelTraining(
    id=training_id,
    spec=ModelTrainingSpec(
        model=ModelIdentity(
            name="wine",
            version="1.0"
        ),
        toolchain="mlflow",
        entrypoint="main",
        work_dir="mlflow/sklearn/wine",
        hyper_parameters={
            "alpha": "1.0"
        },
        resources=ResourceRequirements(
            requests=ResourceList(
                cpu="2024m",
                memory="2024Mi"
            ),
            limits=ResourceList(
                cpu="2024m",
                memory="2024Mi"
            )
        ),
        vcs_name="legion-examples"
    ),
)

packaging_id = "airlfow-wine"
packaging = ModelPackaging(
    id=packaging_id,
    spec=ModelPackagingSpec(
        targets=[Target(name="docker-push", connection_name="docker-ci")],
        integration_name="docker-rest"
    ),
)

deployment_id = "airlfow-wine"
deployment = ModelDeployment(
    id=deployment_id,
    spec=ModelDeploymentSpec(
        min_replicas=1,
    ),
)

model_example_request = {
    "columns": ["alcohol", "chlorides", "citric acid", "density", "fixed acidity", "free sulfur dioxide", "pH",
                "residual sugar", "sulphates", "total sulfur dioxide", "volatile acidity"],
    "data": [[12.8, 0.029, 0.48, 0.98, 6.2, 29, 3.33, 1.2, 0.39, 75, 0.66],
             [12.8, 0.029, 0.48, 0.98, 6.2, 29, 3.33, 1.2, 0.39, 75, 0.66]]
}

dag = DAG(
    'wine_model',
    default_args=default_args,
    schedule_interval=None
)

with dag:
    train = TrainingOperator(
        task_id="training",
        edi_connection_id=edi_connection_id,
        training=training,
        default_args=default_args
    )

    wait_for_train = TrainingSensor(
        task_id='wait_for_training',
        training_id=training_id,
        edi_connection_id=edi_connection_id,
        default_args=default_args
    )

    pack = PackagingOperator(
        task_id="packaging",
        edi_connection_id=edi_connection_id,
        packaging=packaging,
        trained_task_id="wait_for_training",
        default_args=default_args
    )

    wait_for_pack = PackagingSensor(
        task_id='wait_for_packaging',
        packaging_id=packaging_id,
        edi_connection_id=edi_connection_id,
        default_args=default_args
    )

    dep = DeploymentOperator(
        task_id="deployment",
        edi_connection_id=edi_connection_id,
        deployment=deployment,
        packaging_task_id="wait_for_packaging",
        default_args=default_args
    )

    wait_for_dep = DeploymentSensor(
        task_id='wait_for_deployment',
        deployment_id=deployment_id,
        edi_connection_id=edi_connection_id,
        default_args=default_args
    )

    model_predict_request = ModelPredictRequestOperator(
        task_id="model_predict_request",
        model_deployment_name=deployment_id,
        edi_connection_id=edi_connection_id,
        model_connection_id=model_connection_id,
        request_body=model_example_request,
        default_args=default_args
    )

    model_info_request = ModelInfoRequestOperator(
        task_id='model_info_request',
        model_deployment_name=deployment_id,
        edi_connection_id=edi_connection_id,
        model_connection_id=model_connection_id,
        default_args=default_args
    )

    train >> wait_for_train >> pack >> wait_for_pack >> dep >> wait_for_dep
    wait_for_dep >> model_info_request
    wait_for_dep >> model_predict_request
