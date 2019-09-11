from airflow.models import BaseOperator
from airflow.operators.sensors import BaseSensorOperator
from airflow.utils.decorators import apply_defaults
from legion.sdk.clients.edi import WrongHttpStatusCode
from legion.sdk.clients.packaging import ModelPackagingClient, SUCCEEDED_STATE
from legion.sdk.models import ModelPackaging

from legion.airflow.edi import LegionHook
from legion.airflow.training import XCOM_TRAINED_ARTIFACT_KEY

XCOM_PACKAGING_RESULT_KEY = "packaging_result"


class PackagingOperator(BaseOperator):

    @apply_defaults
    def __init__(self,
                 packaging: ModelPackaging,
                 edi_connection_id: str,
                 trained_task_id: str = "",
                 *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.packaging = packaging
        self.edi_connection_id = edi_connection_id
        self.trained_task_id = trained_task_id

    def get_hook(self) -> LegionHook:
        return LegionHook(
            self.edi_connection_id
        )

    def execute(self, context):
        client: ModelPackagingClient = self.get_hook().get_edi_client(ModelPackagingClient)

        try:
            if self.trained_task_id:
                artifact_name = context['task_instance'].xcom_pull(task_ids=self.trained_task_id,
                                                                   key=XCOM_TRAINED_ARTIFACT_KEY)
                print(artifact_name)
                self.packaging.spec.artifact_name = artifact_name

            if self.packaging.id:
                client.delete(self.packaging.id)
        except WrongHttpStatusCode as e:
            if e.status_code != 404:
                raise e

        train = client.create(self.packaging)

        return train.id


class PackagingSensor(BaseSensorOperator):

    @apply_defaults
    def __init__(self,
                 packaging_id: str,
                 edi_connection_id: str,
                 *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.packaging_id = packaging_id
        self.edi_connection_id = edi_connection_id

    def get_hook(self) -> LegionHook:
        return LegionHook(
            self.edi_connection_id
        )

    def poke(self, context):
        client: ModelPackagingClient = self.get_hook().get_edi_client(ModelPackagingClient)

        pack_status = client.get(self.packaging_id).status
        if pack_status.state == SUCCEEDED_STATE:
            results = {result.name: result.value for result in pack_status.results}

            context['task_instance'].xcom_push(XCOM_PACKAGING_RESULT_KEY, results)

            return True

        return False
