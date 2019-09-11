from airflow.models import BaseOperator
from airflow.operators.sensors import BaseSensorOperator
from airflow.utils.decorators import apply_defaults
from legion.sdk.clients.deployment import ModelDeploymentClient, READY_STATE
from legion.sdk.clients.edi import WrongHttpStatusCode
from legion.sdk.models import ModelDeployment

from legion.airflow.edi import LegionHook
from legion.airflow.packaging import XCOM_PACKAGING_RESULT_KEY


class DeploymentOperator(BaseOperator):

    @apply_defaults
    def __init__(self,
                 deployment: ModelDeployment,
                 edi_connection_id: str,
                 packaging_task_id: str = "",
                 *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.deployment = deployment
        self.edi_connection_id = edi_connection_id
        self.packaging_task_id = packaging_task_id

    def get_hook(self) -> LegionHook:
        return LegionHook(
            self.edi_connection_id
        )

    def execute(self, context):
        client: ModelDeploymentClient = self.get_hook().get_edi_client(ModelDeploymentClient)

        try:
            if self.packaging_task_id:
                result = context['task_instance'].xcom_pull(task_ids=self.packaging_task_id,
                                                            key=XCOM_PACKAGING_RESULT_KEY)
                print(result)
                self.deployment.spec.image = result["image"]

            if self.deployment.id:
                client.delete(self.deployment.id)
        except WrongHttpStatusCode as e:
            if e.status_code != 404:
                raise e

        dep = client.create(self.deployment)

        return dep.id


class DeploymentSensor(BaseSensorOperator):

    @apply_defaults
    def __init__(self,
                 deployment_id: str,
                 edi_connection_id: str,
                 *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.deployment_id = deployment_id
        self.edi_connection_id = edi_connection_id

    def get_hook(self) -> LegionHook:
        return LegionHook(
            self.edi_connection_id
        )

    def poke(self, context):
        client: ModelDeploymentClient = self.get_hook().get_edi_client(ModelDeploymentClient)

        dep_status = client.get(self.deployment_id).status

        return dep_status.state == READY_STATE
