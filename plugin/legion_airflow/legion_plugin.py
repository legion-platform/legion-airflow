import logging
from datetime import timedelta

import airflow
import legion.sdk
from airflow.models import BaseOperator
from airflow.operators.sensors import BaseSensorOperator
from airflow.plugins_manager import AirflowPlugin
from airflow.utils.decorators import apply_defaults
from airflow.hooks.base_hook import BaseHook
from legion.sdk.clients.training import ModelTraining

LOGGER = logging.getLogger(__name__)


class Namespace:
    def __init__(self, **kwargs):
        self.__dict__.update(kwargs)


class TrainingOperator(BaseOperator):

    @apply_defaults
    def __init__(self,
                 model_name=None,
                 model_version=None,
                 action='create',
                 connection_name=None,
                 name='?name?',  # TODO
                 toolchain='?tool?chain?',  # TODO
                 workDir='?work?dir?',  # TODO
                 entrypoint='?entry?point?',  # TODO
                 oauth2_token=None,  # TODO replace with OAUTH2 Connection
                 *args,
                 **kwargs):
        super().__init__(*args, **kwargs)
        self.model_name = model_name
        self.model_version = model_version
        self.action = action
        self.name = name
        self.toolchain = toolchain
        self.workDir = workDir
        self.entry_point = entrypoint
        self._conn = BaseHook.get_connection(connection_name if connection_name else 'legion-edi-client')
        self.oauth2_token = oauth2_token

    def execute(self, context):
        LOGGER.info('Legion: {} training model "{}", version {}...'.format(
            self.action.upper(),
            self.model_name,
            self.model_version))
        client = legion.sdk.clients.training.build_client(Namespace(
            edi=self._conn.host,
            token=self.oauth2_token,
            non_interactive=True))
        LOGGER.debug("Client created")

        mt = ModelTraining(
            model_name=self.model_name,
            model_version=self.model_version,
            name=self.name,
            toolchain_type=self.toolchain,
            entrypoint=self.entry_point,
            work_dir=self.workDir,
        )

        action = self.action.lower()
        if action == 'create':
            client.create(mt)
        elif action == 'edit':
            client.edit(mt)
        elif action == 'delete':
            client.delete(mt)
        else:
            raise ValueError("Unsupported Legion Training action {}".format(action))


class TrainingSensor(BaseSensorOperator):

    @apply_defaults
    def __init__(self,
                 model_name=None,
                 model_version=None,
                 connection_name=None,
                 name=None,
                 oauth2_token=None,  # TODO replace with OAUTH2 Connection
                 *args,
                 **kwargs):
        super().__init__(*args, **kwargs)
        self.model_name = model_name
        self.model_version = model_version
        self.name = name
        self._conn = BaseHook.get_connection(connection_name if connection_name else 'legion-edi-client')
        self.oauth2_token = oauth2_token

    def poke(self, context):
        client = legion.sdk.clients.training.build_client(Namespace(
            edi=self._conn.host,
            token=self.oauth2_token,
            non_interactive=True))

        mt = client.get(self.name)
        return mt.state == '?SUCCESS?'  # TODO


class DeploymentOperator(BaseOperator):
    def execute(self, context):
        pass


class DeploymentSensor(BaseSensorOperator):
    def poke(self, context):
        pass


class LegionPlugin(AirflowPlugin):
    # The name of your plugin (str)
    name = 'LegionPlugin'
    # A list of class(es) derived from BaseOperator
    operators = [TrainingOperator, DeploymentOperator]
    # A list of class(es) derived from BaseSensorOperator
    sensors = [TrainingSensor, DeploymentSensor]
