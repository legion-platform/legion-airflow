FROM ubuntu:18.04

ENV DEBIAN_FRONTEND="noninteractive" \
    AIRFLOW_HOME="/home/airflow" \
    LC_ALL="en_US.UTF-8" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    KOPS_VERSION="1.10.0" \
    HELM_VERSION="v2.10.0" \
    KUBECTL_VERSION="v1.10.6"

RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y software-properties-common build-essential libssl-dev libffi-dev zlib1g-dev libjpeg-dev git  \
                        jq xvfb python3 python3-dev python3-pip python3-setuptools \
                        libpython3-dev wget locales apt-transport-https file wget curl git libtiff5-dev libjpeg8-dev \
                        zlib1g-dev tcl8.6-dev tk8.6-dev python-tk python3-tk libfreetype6-dev liblcms2-dev \
                        libwebp-dev libharfbuzz-dev libfribidi-dev tcl8.6-dev tk8.6-dev python-tk python3-tk libpcre3 \
                        libpcre3-dev locales cron libkrb5-dev libsasl2-dev libssl-dev libffi-dev libblas-dev \
                        liblapack-dev sudo iputils-ping openssh-client libpq-dev sshpass redis-tools netcat \
                        libmysqlclient-dev && \
    apt-get clean && apt-get autoclean && \
    rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

COPY default_locale /etc/default/locale
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 && \
    chmod 0755 /etc/default/locale

RUN wget -O /usr/local/bin/kops \
            https://github.com/kubernetes/kops/releases/download/${KOPS_VERSION}/kops-linux-amd64 && \
    chmod a+x /usr/local/bin/kops && \
    wget -O /usr/local/bin/kubectl \
            https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod a+x /usr/local/bin/kubectl && \
    mkdir /tmp/helm && \
    wget -O /tmp/helm/helm.tar.gz https://kubernetes-helm.storage.googleapis.com/helm-${HELM_VERSION}-linux-amd64.tar.gz && \
    tar xzf /tmp/helm/helm.tar.gz -C /tmp/helm && \
    mv /tmp/helm/linux-amd64/helm /usr/local/bin/helm && rm -rf /tmp/helm

WORKDIR /src/legion_airflow/

RUN pip3 install --disable-pip-version-check --upgrade pip==18.1 pipenv==2018.10.13

ADD Pipfile ./
RUN pipenv install --system --dev --skip-lock

ADD ../../legion_airflow /src/legion_airflow
RUN cd /src/legion_airflow \
  && python setup.py develop \
  && python setup.py sdist \
  && python setup.py bdist_wheel