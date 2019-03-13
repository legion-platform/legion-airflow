FROM ubuntu:18.04

ENV DEBIAN_FRONTEND="noninteractive"

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

COPY k8s/agent/default_locale /etc/default/locale
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 && \
    chmod 0755 /etc/default/locale

# Install Kops
ENV KOPS_VERSION=1.10.0
ADD https://github.com/kubernetes/kops/releases/download/${KOPS_VERSION}/kops-linux-amd64 /usr/local/bin/kops
RUN chmod a+x /usr/local/bin/kops

# Install Helm
ENV HELM_VERSION=v2.10.0
ADD https://kubernetes-helm.storage.googleapis.com/helm-${HELM_VERSION}-linux-amd64.tar.gz /tmp/helm/
RUN tar xzf /tmp/helm/helm-${HELM_VERSION}-linux-amd64.tar.gz -C /tmp/helm && \
    mv /tmp/helm/linux-amd64/helm /usr/local/bin/helm && rm -rf /tmp/helm

# Install additional tools for build purposes
RUN pip3 install Sphinx==1.8.0 sphinx_rtd_theme==0.4.1 sphinx-autobuild==0.7.1 \
    recommonmark==0.4.0 ansible==2.7.2 awscli==1.16.19 yq==2.7.2

# Update locale for pipenv compatibility
ENV LC_ALL="en_US.UTF-8" \
    LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8"

COPY legion_airflow/Pipfile legion_airflow/Pipfile.lock /tmp/
RUN pip3 install --disable-pip-version-check --upgrade pip==9.0.3 pipenv==2018.10.13 && \
    cd /tmp/ && pipenv install --system --dev

WORKDIR /tmp
