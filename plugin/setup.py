#
#    Copyright 2018 IQVIA
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
from setuptools import setup
import os

PACKAGE_ROOT_PATH = os.path.dirname(os.path.abspath(__file__))

setup(name='legion_airflow',
      version='1.0',
      description='External library for airflow',
      url='https://github.com/legion-platform/legion-airflow',
      author='Legion team',
      author_email='legion-dev@googlegroups.com',
      license='Apache v2',
      packages=['legion_airflow'],
      include_package_data=True,
      scripts=[],
      zip_safe=False)
