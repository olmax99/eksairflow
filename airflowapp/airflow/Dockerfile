FROM python:3.7-slim-stretch

# Never prompts the user for choices on installation/configuration of packages
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

# Airflow
ARG AIRFLOW_VERSION=1.10.4
ARG AIRFLOW_USER_HOME=/usr/local/airflow
ARG AIRFLOW_DEPS=""
ARG PYTHON_DEPS=""
ENV AIRFLOW_HOME=${AIRFLOW_USER_HOME}

# Define en_US.
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8

ENV PYTHONUNBUFFERED 1

# Custom passwords (i.e. connections)
# ARG USER_LOGIN
# ARG USER_PASSWORD
#
# ENV USER_LOGIN=$USER_LOGIN
# ENV USER_PASSWORD=$USER_PASSWORD

RUN set -ex \
    && buildDeps=' \
        freetds-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        libpq-dev \
        git \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        freetds-bin \
        build-essential \
        default-libmysqlclient-dev \
        apt-utils \
        curl \
        rsync \
        netcat \
        locales \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && useradd -ms /bin/bash -d ${AIRFLOW_USER_HOME} airflow \
    && pip install -U pip setuptools wheel \
    && pip install pytz \
    && pip install pyOpenSSL \
    && pip install ndg-httpsclient \
    && pip install pyasn1 \
    && pip install apache-airflow[crypto,celery,postgres,hive,jdbc,mysql,ssh${AIRFLOW_DEPS:+,}${AIRFLOW_DEPS}]==${AIRFLOW_VERSION} \
    && pip install 'redis==3.2' \
    && if [ -n "${PYTHON_DEPS}" ]; then pip install ${PYTHON_DEPS}; fi \
    && apt-get purge --auto-remove -yqq $buildDeps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base \

    # Additional Google Cloud dependencies
    # && pip3 install --upgrade google-cloud-storage \
    # && pip3 install --upgrade google-api-python-client \
    # && pip3 install --upgrade httplib2 \
    # && pip3 install pandas-gbq \
    # && pip3 install pyarrow \

    # prometheus compatible data endpoint
    && pip3 install 'airflow-exporter==1.0' \

    # FOR USING PIPFILE ENVIRONMENTS
    && pip3 install --no-cache-dir -U pip pipenv

COPY entrypoint.sh /entrypoint.sh
COPY ./airflow.cfg ${AIRFLOW_USER_HOME}/airflow.cfg

# Custom GoogleCloudCredentials and additional connections < NOT possible to copy dynamic file names
# COPY ./example-setting-123456-u4uts9sa1234.json /usr/local/airflow/secrets/gcp_key.json
COPY ./create_connections.py ${AIRFLOW_USER_HOME}/create_connections.py

RUN chmod 755 ${AIRFLOW_USER_HOME}/create_connections.py
RUN chown -R airflow: ${AIRFLOW_USER_HOME}


EXPOSE 8080 5555 8793

USER airflow
WORKDIR ${AIRFLOW_USER_HOME}
ENTRYPOINT ["/entrypoint.sh"]

# NOTE: All packages excl. [--dev] will be install directly on webserver
# COPY ./Pipfile ${AIRFLOW_HOME}/Pipfile
# COPY ./Pipfile.lock ${AIRFLOW_HOME}/Pipfile.lock

# Install Pipfile.lock packages directly in webserver
# RUN pipenv lock -r > req.txt && pip install -r req.txt --user


# set default arg for entrypoint
CMD ["webserver"]
