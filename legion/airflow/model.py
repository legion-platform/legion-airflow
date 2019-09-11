import typing

from airflow.models import BaseOperator
from airflow.utils.decorators import apply_defaults
from legion.sdk.clients.deployment import ModelDeploymentClient
from legion.sdk.clients.model import ModelClient

from legion.airflow.edi import LegionHook


class ModelPredictRequestOperator(BaseOperator):

    @apply_defaults
    def __init__(self,
                 model_deployment_name: str,
                 edi_connection_id: str,
                 model_connection_id: str,
                 request_body: typing.Any,
                 md_role_name: str = "",
                 *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.model_deployment_name = model_deployment_name
        self.request_body = request_body
        self.model_connection_id = model_connection_id
        self.edi_connection_id = edi_connection_id
        self.md_role_name = md_role_name

    def get_hook(self) -> LegionHook:
        return LegionHook(
            self.edi_connection_id,
            self.model_connection_id
        )

    def execute(self, context):
        md_client: ModelDeploymentClient = self.get_hook().get_edi_client(ModelDeploymentClient)

        model_jwt = md_client.get_token(md_role_name=self.md_role_name)
        model_client: ModelClient = self.get_hook().get_model_client(self.model_deployment_name, model_jwt)

        resp = model_client.invoke(**self.request_body)
        print(resp)

        return resp


class ModelInfoRequestOperator(BaseOperator):

    @apply_defaults
    def __init__(self,
                 model_deployment_name: str,
                 edi_connection_id: str,
                 model_connection_id: str,
                 md_role_name: str = "",
                 *args, **kwargs):
        super().__init__(*args, **kwargs)

        self.model_deployment_name = model_deployment_name
        self.model_connection_id = model_connection_id
        self.edi_connection_id = edi_connection_id
        self.md_role_name = md_role_name

    def get_hook(self) -> LegionHook:
        return LegionHook(
            self.edi_connection_id,
            self.model_connection_id
        )

    def execute(self, context):
        md_client: ModelDeploymentClient = self.get_hook().get_edi_client(ModelDeploymentClient)

        model_jwt = md_client.get_token(md_role_name=self.md_role_name)
        model_client: ModelClient = self.get_hook().get_model_client(self.model_deployment_name, model_jwt)

        resp = model_client.info()
        print(resp)

        return resp
