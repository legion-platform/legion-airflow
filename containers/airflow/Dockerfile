FROM ubuntu:18.04

ENV DEBIAN_FRONTEND="noninteractive" \
    AIRFLOW_HOME="/home/airflow"

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        python3 g++ apt-utils build-essential python3-dev python3-pip python3-setuptools libpython3-dev \
        apt-transport-https file wget curl git locales sudo iputils-ping openssh-client libpq-dev sshpass redis-tools netcat \
        libmysqlclient-dev && \
    apt-get clean -y && apt-get autoclean -y && \
    rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

# Set locale
COPY containers/agent/default_locale /etc/default/locale
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 && \
    chmod 0755 /etc/default/locale && \
    useradd -ms /bin/bash -d ${AIRFLOW_HOME} airflow

# Install rest api plugin
RUN cd ${AIRFLOW_HOME} && \
    mkdir temp && cd temp && \
    git clone https://github.com/teamclairvoyant/airflow-rest-api-plugin.git && \
    mkdir -p ${AIRFLOW_HOME}/plugins && \
    touch ${AIRFLOW_HOME}/plugins/__init__.py && \
    mv ${AIRFLOW_HOME}/temp/airflow-rest-api-plugin/plugins ${AIRFLOW_HOME}/plugins/rest_api && \
    rm -rf ${AIRFLOW_HOME}/temp

# Update locale for pipenv compatibility
ENV LC_ALL="en_US.UTF-8" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8"

# Install Legion package
RUN pip3 install $pip_extra_index_params legion$pip_legion_version_string

# Copy legion-airflow soures and set permissions
COPY legion_airflow/ ${AIRFLOW_HOME}/
COPY containers/airflow/create_secrets.py containers/airflow/init.sh ${AIRFLOW_HOME}/
RUN chown -R airflow: ${AIRFLOW_HOME} && chmod -R 775 ${AIRFLOW_HOME} && \
    chmod a+x ${AIRFLOW_HOME}/init.sh

# Install legion-airflow dependencies
RUN pip3 install --disable-pip-version-check --upgrade pip==9.0.3 pipenv==2018.10.13 && \
    cd ${AIRFLOW_HOME} && pipenv install --system --deploy --python python3 

# TODO resolve hack for dependency conflict
RUN pip3 install Jinja2==2.10

# Install legion-airflow from sources
RUN cd ${AIRFLOW_HOME} && python3 setup.py install

USER airflow
WORKDIR ${AIRFLOW_HOME}

ENTRYPOINT ["sh", "/home/airflow/init.sh"]