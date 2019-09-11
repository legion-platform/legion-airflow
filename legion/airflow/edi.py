import json

import requests
from airflow.hooks.base_hook import BaseHook
from airflow.models import Connection
from legion.sdk.clients.model import ModelClient, calculate_url


class LegionHook(BaseHook):

    def __init__(self, edi_connection_id=None, model_connection_id=None):
        super().__init__(None)

        self.edi_connection_id = edi_connection_id
        self.model_connection_id = model_connection_id

    def get_edi_client(self, target_client_class):
        edi_conn = self.get_connection(self.edi_connection_id)
        self.log.info(edi_conn)

        return target_client_class(f'{edi_conn.schema}://{edi_conn.host}', self._get_token(edi_conn))

    def get_model_client(self, model_route_name: str, model_jwt: str) -> ModelClient:
        model_conn = self.get_connection(self.model_connection_id)
        self.log.info(model_conn)

        return ModelClient(calculate_url(
            host=f'{model_conn.schema}://{model_conn.host}',
            model_route=model_route_name
        ), model_jwt)

    def _get_token(self, conn: Connection) -> str:
        """
        Authorize test user and get access token.

        :param Airlfow EDI connection TODO: add example configuration
        :return: access token
        """
        print(conn.extra, type(conn.extra))
        extra = json.loads(conn.extra)
        print(extra, type(extra))
        auth_url = extra["auth_url"]

        try:
            response = requests.post(
                auth_url,
                data={
                    'grant_type': 'password',
                    'client_id': extra["client_id"],
                    'client_secret': extra["client_secret"],
                    'username': conn.login,
                    'password': conn.password,
                    'scope': extra['scope']
                }
            )
            response_data = response.json()

            # Parse fields and return
            id_token = response_data.get('id_token')
            token_type = response_data.get('token_type')
            expires_in = response_data.get('expires_in')

            self.log.info('Received %s token with expiration in %d seconds', token_type, expires_in)

            return id_token
        except requests.HTTPError as http_error:
            raise Exception(f'Can not authorize user {conn.login} on {auth_url}: {http_error}') from http_error
