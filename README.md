# AWS Airflow Build

This project is a fully functional Airflow Build using Cloudformation and EC2 instances along with a docker-compose local development setup.

**Goal:**
This airflow project is enabling both interaction with a local minikube environment for testing and development 
and with a custom Kubernetes production environment EKS on AWS. 

The demo DAG intends to bid for spot instances and is scaling an external ECS cluster accordingly.

---

![kubeairflow-graph](images/kubeairflow.png)


## Project Design

The Airflow AWS deployment is based on [https://github.com/villasv/aws-airflow-stack](https://github.com/villasv/aws-airflow-stack). There is a VPN Bastion Host 
implemented, which strictly allows ingress from internal network IPs only. The Airflow webserver can only be 
reached with the VPN activated.

In a future version all Airflow EC2 services will be replaced by an EKS deployment.

---


#### Local Docker-Compose Build

**USEFUL COMMANDS:**
```
$ docker-compose -f docker-compose.testing.yml exec webserver sh -c "airflow list_dags"

# Run a task without scheduling, find date time in **Graph View**
# NOTE: Take task_id always from OperatorInstance
$ docker-compose -f docker-compose.testing.yml exec webserver sh -c "airflow test prosp_operator_dag prosp_operator_task 2018-05-08T09:55:57.966423+00:00"

# NOTE: Always ensure that a [new http Connection](#### Managing Connections) is created in Admin > Connections 
$ docker-compose -f docker-compose.testing.yml exec webserver sh -c "airflow test demo_gcc_llife_prod_report_DAG prosp_save_file_to_gcs_operator 2018-05-08T09:55:57.966423+00:00"

$ docker-compose -f docker-compose.testing.yml exec webserver sh -c "airflow test llife_prod_report_dag wait_for_prod_report 2018-05-08T09:55:57.966423+00:00"

# Schedule all available dags
$ docker-compose -f docker-compose.testing.yml exec webserver sh -c "airflow scheduler"

$ docker-compose -f docker-compose.testing.yml exec webserver sh -c "airflow upgradedb"

# FlaskWorker
$ docker-compose -f docker-compose.testing.yml exec webserver sh -c "airflow connections --add --conn_id local_webapi_docker --conn_type http --conn_host webapi --conn_port 5000"


```

  

## Getting Started. 

### 1. Preparing the Environment. 

#### Prerequisites

- [Optionally] Pyenv
- Pipenv integrated with Pyenv
- Python Version >=3.7
- Docker installed
- Docker-Compose
- AWS account + awscli installed

#### Install

Pyenv and Pipenv is the new way to go for Python version control and virtual environments. Visit [SecretOfPythonPath](https://github.com/olmax99/secretofpythonpath) project 
for how to get started.

Docker should be installed on the system, else please read the official Docker docs.

- Step 1: Set the Python Version
- Step 2: Create a new Pipenv.lock file if not present in the composer directory
- Step 3: `dockerd` needs to be configured in order to be a [target to Prometheus](https://docs.docker.com/config/thirdparty/prometheus/).

**Linux:**

Create file is it does not exist. In `/etc/docker/daemon.json`:

```
{
  "metrics-addr" : "127.0.0.1:9323",
  "experimental" : true
}


```

- Optionally: Postgres Database can only be accessed locally via docker-compose (uncomment accordingly)

Find Postgres Admin at `localhost:8000`

```
PGADMIN_DEFAULT_EMAIL: pgadmin4@pgadmin.org
PGADMIN_DEFAULT_PASSWORD: pgadmin


```

## Run in development mode

In directory `airflowapp`:
```
$ make compose

```

### 1. Adding local Connections for development and testing

**STEP 1:** Add connection programmatically

- In `airflowapp/create_connections.py` add the code according to previous examples provided 

**STEP 2:** Add passwords and logins to environment variables

- In `.dev.override.env` add the appropriate environment variable, I.e.

```
MY_CUSTOM_LOGIN=username
MY_CUSTOM_PASSWORD=super_secret

``` 

**STEP 3:** Adjust Dockerfile

All custom variables need to be added in the section `# Custom passwords (i.e. connections)`.

```
# NOTE: ARGs are mandatory for Dockerfile environment variable initialization!!
ARG MY_CUSTOM_LOGIN
ARG MY_CUSTOM_PASSWORD

ENV MY_CUSTOM_LOGIN=$MY_CUSTOM_LOGIN
ENV MY_CUSTOM_PASSWORD=$MY_CUSTOM_PASSWORD

```

From then on, all variables can be used in `create_connections.py`.


### 2. Commit changes into staging environment

**NOTE:** It is NOT recommended to directly deploy into production. Cloudformation allows for
keeping two identical and complete environments, and this should be anyways restricted via IAM user
policies.

1. Stop the local docker-compose environment
2. Push a new revision bundle via CodeDeploy

In directory `airflowapp`:
```
$ make down

$ make deploy

```


## Run in production

The production environment is the AWS EC2 ScalingGroup environment. Interact with all the   
respective resources via the AWS API or the AWS Console.

#### 1. Add all custom connections

1. To be added

```
...


```

#### 2. Create new  Production Environment

**STEP 1:** Create the CloudFormation environment.

```
$ make cluster
	
```

**STEP 2:** Deploy the Airflow application

In `airflowapp`:
```
$ export stack_name=<your stack>

$ make deploy

```

#### 3. Connect to Airflow Webserver

**Linux**:

- Create VPN certificates
- Activate VPN `*.ovpn` file via nmcli or network settings

```
$ make vpn

```

In Browser: http://<internal webserver instance IP>:8080



## Running the Tests. 


### FAQ

- How to log-in to webserver/worker/scheduler instance(s) for debugging or admin tasks?

Use the Console `AWS Systems Manager`/`Session Manager` for secure login without the need of SSH
or the need of going through Bastion Host.


- How to login into the airflow database for debugging?


Install the psql client inside the Bastion Host (NOT directly available in AMZNLINUX2):
```
sudo yum groupinstall "Development Tools" -y
sudo yum install readline readline-devel systemd-devel -y
wget -O - https://ftp.postgresql.org/pub/source/v11.4/postgresql-11.4.tar.bz2 | tar jxf -
cd postgresql-11.4

make
sudo make install

```


- How does the worker load the deployment resources into airflow?

Airflow is installed as a regular pip3 package in `/usr/local/lib/python3.7/site-packages`. The 
`airflow.service` is started under systemd through `scripts/cdapp_start.sh` defined in `appspec.yml` 
every time a new CodeDeploy bundle is set as target revision (each `aws deploy` invocation).

`/etc/sysconfig/airflow` defines `AIRFLOW_HOME=/airflow`. 

- Airflow loads `$AIRFLOW_HOME/dags` into the database every time `/usr/local/bin/airflow upgradedb` 
  is triggered (each `aws deploy` invocation).
- A simple Airflow plugin manager is loading all python modules from the `$AIRFLOW_HOME/plugins` directory.

`/usr/lib/systemd/system/airflow.service` defines which service is being started within a new auto
scaling instance.

```
[Service]
...
ExecStart=/usr/bin/turbine

```

`airflow.service` will be started accordingly:

1. Webserver
```
airflow.service
   Loaded: loaded (/usr/lib/systemd/system/airflow.service; enabled; vendor preset: disabled)
   Active: active (running) since Sun 2019-11-10 16:04:43 UTC; 7min ago
 Main PID: 16841 (/usr/bin/python)
   CGroup: /system.slice/airflow.service
           ├─16841 /usr/bin/python3 /usr/local/bin/airflow webserver
           ├─16850 gunicorn: master [airflow-webserver]
           ├─16902 [ready] gunicorn: worker [airflow-webserver]
           ├─16915 [ready] gunicorn: worker [airflow-webserver]

```

2. Worker
```
airflow.service
   Loaded: loaded (/usr/lib/systemd/system/airflow.service; enabled; vendor preset: disabled)
   Active: active (running) since Sun 2019-11-10 16:04:43 UTC; 13min ago
 Main PID: 16948 ([celeryd: celer)
   CGroup: /system.slice/airflow.service
           ├─16948 [celeryd: celery@ip-10-0-10-200.eu-central-1.compute.internal:MainProcess] -active- (worker)
           ├─16956 /usr/bin/python3 /usr/local/bin/airflow serve_logs
           ├─16957 [celeryd: celery@ip-10-0-10-200.eu-central-1.compute.internal:ForkPoolWorker-1]
           ├─16958 [celeryd: celery@ip-10-0-10-200.eu-central-1.compute.internal:ForkPoolWorker-2]

```

3. Scheduler
```
airflow.service
   Loaded: loaded (/usr/lib/systemd/system/airflow.service; enabled; vendor preset: disabled)
   Active: active (running) since Sun 2019-11-10 16:04:45 UTC; 14min ago
 Main PID: 16781 (/usr/bin/python)
   CGroup: /system.slice/airflow.service
           ├─16781 /usr/bin/python3 /usr/local/bin/airflow scheduler
           └─16790 airflow scheduler -- DagFileProcessorManager

```

- How is a simple airflow project being build with docker?

  * [https://github.com/puckel/docker-airflow](https://github.com/puckel/docker-airflow)

- Can an airflow task (from within docker) trigger another docker to do something?

  * YES! Within tasks there are operators, which handle the execution of them. There is a
Specific **DockerOperator** for this:

  * [https://github.com/apache/airflow/docker_operator.py](https://github.com/apache/airflow/blob/master/airflow/operators/docker_operator.py)

- Where can I find the DAG directory and how to define them?

  * It is defined in `airflow.cfg`: dags_folder = /usr/local/airflow/dags

- Is it possible to let tasks communicate between each other?

  * Yes, the feature is called **XCom**.

- What is the difference between LocalExecutor, SequentialExecutor, and CeleryExecutor?

  * The LocalExecutor can parallelize task instances locally, but only works in a simple
  single-container-like environment (even though there is an option of connecting custom data bases, 
  i.e. replacing sqlite with postgreSQL.

- How to set up Postgres usage instead of local sqlite?

  * To configure Airflow to use Postgres rather than the default Sqlite3, go to airflow.cfg and 
  update this configuration to `LocalExecutor`

Airflow.cfg

```
# The executor class that airflow should use. Choices include
# SequentialExecutor, LocalExecutor, CeleryExecutor
executor = LocalExecutor


```

- How can single tasks from a dag file be tested without actually running? 


- How to run execute each operator run on a different cluster node?


- Where can the output log from an executed task be reviewed in the GUI?

  * In DAG overview go to the respective DAG > select Graph View > select the task to review the log for > View Log

- What is the context inside an Operator's `execute(self, context)` function?

  * The context of a task may look like this:  


```
{'dag': <DAG: prosp_operator_dag>,
 'ds': '2018-05-08',
 'next_ds': '2018-05-08',
 'prev_ds': '2018-05-07',
 'ds_nodash': '20180508',
 'ts': '2018-05-08T09:55:57.966423+00:00',
 'ts_nodash': '20180508T095557.966423+0000',
 'yesterday_ds': '2018-05-07',
 'yesterday_ds_nodash': '20180507',
 'tomorrow_ds': '2018-05-09',
 'tomorrow_ds_nodash': '20180509',
 'END_DATE': '2018-05-08',
 'end_date': '2018-05-08',
 'dag_run': None,
 'run_id': None,
 'execution_date': <Pendulum [2018-05-08T09:55:57.966423+00:00]>,
 'prev_execution_date': datetime.datetime(2018, 5, 7, 12, 0, tzinfo=<TimezoneInfo [UTC, GMT, +00:00:00, STD]>),
 'next_execution_date': datetime.datetime(2018, 5, 8, 12, 0, tzinfo=<TimezoneInfo [UTC, GMT, +00:00:00, STD]>),
 'latest_date': '2018-05-08',
 'macros': <module 'airflow.macros' from '/usr/local/lib/python3.6/site-packages/airflow/macros/__init__.py'>,
 'params': {},
 'tables': None,
 'task': <Task(ProspOperator): prosp_operator_task>,
 'task_instance': <TaskInstance: prosp_operator_dag.prosp_operator_task 2018-05-08T09:55:57.966423+00:00 [None]>,
 'ti': <TaskInstance: prosp_operator_dag.prosp_operator_task 2018-05-08T09:55:57.966423+00:00 [None]>,
 'task_instance_key_str': 'prosp_operator_dag__prosp_operator_task__20180508',
 'conf': <module 'airflow.configuration' from '/usr/local/lib/python3.6/site-packages/airflow/configuration.py'>,
 'test_mode': True,
 'var': {'value': None, 'json': None},
 'inlets': [],
 'outlets': []}


```

## Next Steps

### 2. Architecture Stuff (ToDos)

- monitor deployments and set up Auto Scaling notifications

## Author

OlafMarangone
Contact [olmighty99@gmail.com](mailto:olmighty99@gmail.com)







