#   Copyright 2018 Bruno Faria
#   Repository: https://github.com/brunocfnba/docker-airflow
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

FROM ubuntu:18.04

ENV DEBIAN_FRONTEND="noninteractive" \
    AIRFLOW_HOME="/home/airflow" \
    LC_ALL="en_US.UTF-8" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8"

RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        python3 g++ apt-utils build-essential python3-dev python3-pip python3-setuptools libpython3-dev \
        apt-transport-https file wget curl git libtiff5-dev libjpeg8-dev zlib1g-dev tcl8.6-dev tk8.6-dev python-tk \
        python3-tk libfreetype6-dev liblcms2-dev libwebp-dev libharfbuzz-dev libfribidi-dev tcl8.6-dev tk8.6-dev \
        python-tk python3-tk libpcre3 libpcre3-dev locales cron libkrb5-dev libsasl2-dev libssl-dev libffi-dev \
        libblas-dev liblapack-dev sudo iputils-ping openssh-client libpq-dev sshpass redis-tools netcat \
        libmysqlclient-dev && \
    apt-get clean -y && apt-get autoclean -y && \
    rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

COPY default_locale /etc/default/locale
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 && \
    chmod 0755 /etc/default/locale && \
    useradd -ms /bin/bash -d ${AIRFLOW_HOME} airflow

RUN cd "${AIRFLOW_HOME}" && \
    mkdir temp && cd temp && \
    git clone https://github.com/teamclairvoyant/airflow-rest-api-plugin.git && \
    mkdir -p "${AIRFLOW_HOME}"/plugins && \
    touch "${AIRFLOW_HOME}"/plugins/__init__.py && \
    mv "${AIRFLOW_HOME}"/temp/airflow-rest-api-plugin/plugins "${AIRFLOW_HOME}"/plugins/rest_api && \
    rm -rf "${AIRFLOW_HOME}"/temp

# TODO: return Pipfile.lock and remove "--skip-lock"
COPY ../../Pipfile ./

RUN pip3 install --disable-pip-version-check --upgrade pip==9.0.3 pipenv==2018.10.13 && \
    pipenv install --system --deploy --skip-lock --python python3

COPY create_secrets.py init.sh "${AIRFLOW_HOME}/"

RUN chown -R airflow: ${AIRFLOW_HOME} && chmod -R 775 ${AIRFLOW_HOME} && \
    chmod a+x "${AIRFLOW_HOME}"/init.sh

# TODO: reduce
COPY ./ "${AIRFLOW_HOME}/"
RUN pip3 install -e ${AIRFLOW_HOME}

USER airflow
WORKDIR ${AIRFLOW_HOME}

ENTRYPOINT ["sh"]
CMD ["${AIRFLOW_HOME}/init.sh"]


