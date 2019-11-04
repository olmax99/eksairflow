# EKS Airflow Build

This airflow project is enabling both interaction with a local docker-compose build for testing and development 
and with a custom Kubernetes production environment EKS on AWS. 

The demo workflow intends to bid for spot instances and is scaling an external ECS cluster accordingly.

---


## Project Design

NOTE: All finished tasks can be viewed in [CHANGELOG.md](CHANGELOG.md)


### 1. Deploy

X Understand `villasv/aws-airflow-stack`: Turbine

- [Optionally] Use AWS Systems Manager instead of Bastion Host 

- Understand Code deploy in [https://github.com/villasv/aws-airflow-stack](https://github.com/villasv/aws-airflow-stack) and compare to 'sync bucket method' (see `2. Upstream your files`)

- Create nested cfn stack with a master template, private subnets + vpn


### 2. Airflow Stuff

- verify and confirm that function is **idempotent**

- understand the [airflow scheduler](https://cwiki.apache.org/confluence/display/AIRFLOW/Scheduler+Basics). 

- adjust airflow scheduler datetime to the current tz (or utc)

- store passwords as encrypted  

- store all variables in a [single json variable](https://medium.com/datareply/airflow-lesser-known-tips-tricks-and-best-practises-cf4d4a90f8f). 

- Do not load dags with prefix `archive_`

---


#### Local Docker-Compose Build

```
# default AIRFLOW_HOME = /usr/local/airflow
# plugins_folder = /usr/local/airflow/plugins
# dags_folder = /usr/local/airflow/dags
# More information see 'airflow.cfg'

$ docker-compose -f docker-compose.testing.yml up --build

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


## Project Structure 

```
composer
├── CHANGELOG.md
├── README.md
├── docker-compose.testing.yml
├── docker-compose.development.yml
└── airflowapp
    ├── Dockerfile
    ├── Pipfile
    ├── Pipfile.lock
    ├── airflow.cfg
    ├── dags						--> SYNC TO S3 BUCKET
    │   └── ...
    ├── data						<-- SYNC FROM S3 BUCKET (gitignore)
    ├── entrypoint.sh
    ├── ekssync.sh
    ├── logs						<-- SYNC FROM S3 BUCKET (gitignore)
    │   ├── airflow_monitoring
    │   └── ...
    └── plugins						--> SYNC TO S3 BUCKET
        ├── custom_plugins.py
        └── ...


```

  

## Getting Started. 


**NOTE:** It is recommended to open the project in PyCharm on directory `airflowapp` as top directory !!!  


### 1. Preparing the Environment. 
  


#### Prerequisites

- [Optionally] Pyenv
- Pipenv integrated with Pyenv
- Python Version 3.6.8
- Docker installed

#### Install

Pyenv and Pipenv is the new way to go for Python version control and virtual environments. Visit [SecretOfPythonPath](https://github.com/olmax99/secretofpythonpath) project for how to get started.  

Docker should be installed on the system, else please read the official Docker docs.

##### Step 1: Set the Python Version

```
# In directory airflowapp
$ ls -al   # you should have a local file .python-version in the top of project directory

# Optionally
$ pyenv local 3.7.4
$ python -V         # Python 3.7.4


```

##### Step 2: Create a new Pipenv.lock file if not present in the composer directory

```
# Will create the virtual environment folders along with a Pipfile.lock
$ cd composer && pipenv install


```

##### Postgres Database can only be accessed locally

Find Postgres Admin at `localhost:8000`

```
PGADMIN_DEFAULT_EMAIL: pgadmin4@pgadmin.org
PGADMIN_DEFAULT_PASSWORD: pgadmin


```


##### Step 4: Docker deamon

**NOTE:** The Docker needs to be configured in order to be a [target to Prometheus](https://docs.docker.com/config/thirdparty/prometheus/).

**Linux:**

Create file is it does not exist. In `/etc/docker/daemon.json`:

```
{
  "metrics-addr" : "127.0.0.1:9323",
  "experimental" : true
}


```


## Run Project in the preferred environment

### Prepare custom environment variables

Create a file `.dev.override.env` containing at the minimum the following variables:

```
Credentials and target URLs

```


### Run in development mode

```
$ docker-compose -f docker-compose.development.yml up --build

```

##### Explanation for using FUSE:

In the current development setup, it is required that all files written to `composer/data` 
will simultaneously written to this project's dedicated *Google Cloud Development Bucket*.

This is achieved by the following file system mappings:

1. The directory `airflowapp/data` inside docker is a volume mapped to `airflowapp/local_data`.
2. The directory `airflowapp/local_data` is directly mounted to the dedicated *Google Cloud Development Bucket*.


#### Adding local Connections for development and testing

STEP 1: Add connection programmatically

- In `airflowapp/create_connections.py` add the code according to previous examples provided 

STEP 2: Add passwords and logins to environment variables

- In `.dev.override.env` add the appropriate environment variable, I.e.

```
MY_CUSTOM_LOGIN=username
MY_CUSTOM_PASSWORD=super_secret

``` 

STEP 3: Adjust Dockerfile

All custom variables need to be added in the section `# Custom passwords (i.e. connections)`.

```
# NOTE: ARGs are mandatory for Dockerfile environment variable initialization!!
ARG MY_CUSTOM_LOGIN
ARG MY_CUSTOM_PASSWORD

ENV MY_CUSTOM_LOGIN=$MY_CUSTOM_LOGIN
ENV MY_CUSTOM_PASSWORD=$MY_CUSTOM_PASSWORD

```

From then on, all variables can be used in `create_connections.py`.


#### Sync local 'gcsfuse/data' directory with S3 Bucket

**RexRay** ...


### Run in production

The production environment is the managed Google Cloud Composer environment. Interact with all the   
respective resources via the Google Cloud API or the Google Console.

#### 1. Add all custom connections

1. To be added

```
...


```

#### Create new Cloud Composer Production Environment

```
$ make eksairflow

	
```


[Airflow Default Config](https://github.com/apache/airflow/blob/master/airflow/config_templates/default_airflow.cfg)


#### Sync local directory [BEWARE OF DATA LOSS!!]

---  

NOTE: NEVER MANUALLY SYNC REMOTE TO LOCAL, ALWAYS LOCAL TO REMOTE !!! USE RSYNC BASH SCRIPT INSTEAD !!!


```
# Bash environment needs destination 
$ export EKSAIRFLOW_S3=<Bucket Name>

# Use bash script for syncing in two directions
$ bash eksairflow_sync.sh


```



## Running the Tests. 


### Local Docker Environment


#### Start Airflow Docker Build

```
$ docker-compose -f docker-compose.testing.yml up --build


```



## Monitoring - StackDriver

...



### i. Log aggregation

[Usage of advanced log filters](https://cloud.google.com/logging/docs/view/advanced-filters#finding-quickly)

### ii. Crash Reporting

### iii. Application Performance

### iv. Monitoring

#### a. Uptime Check

#### b. ...


### FAQ


## General Concepts. 
  


### 1. Access the EKS Airflow Environment


The main administrative GUI access can be done via **'Environment details'**.	

Apart from configuration settings, there are the two main EKS Airflow resources accessible:    


#### The Kubernetes Engine:   
  

1. Kubernetes **Cluster** Overview. 

2. Kubernetes **Pods** access. 

  - airflow-worker (3/3) via 'CeleryExecutor'

  - airflow-scheduler Pod (1/1).   

  - airflow-redis Pod (1/1). 

  - airflow-monitoring Pod (1/1).   


#### The Airflow resources:
  
##### 1. Airflow Bucket. 
 
  - `/dags`. 

  - `/plugins`. 

  - `/data` can be used from EKS Airflow directly as the FUSE filesystem is mounted at '/home/airflow/bucket/data'. Note that no directories `/`can be used that way as FUSE only has one root directory. Use an S3Operator in order to move files to the appropriate locations.  

  - `/logs`. 

---

NOTE:  
 
As a naming convention, a file stored in the root FUSE directory '/home/airflow/bucket/data' should always use `root_fuse_path` 
as a path variable and *NEVER* ***file_path*** !!! 



##### 2. Airflow Webserver


#### Managing Connections In Local Airflow Docker

NOTE: Http Connection need to be registered in Admin > Connection.

##### MacOS and Windows:

*Airflow GUI* at `localhost:8080`   


Admin > Connections > Create

- Conn_id: &nbsp;&nbsp;&nbsp;&nbsp; local_webapi_docker

- Conn_Type: &nbsp;&nbsp;&nbsp;&nbsp; HTTP

- Host: &nbsp;&nbsp;&nbsp;&nbsp; `host.docker.internal`

- Port: 80
  
  
##### From Terminal:
 
``` 
$ docker exec -i dockerairflow_webserver_1 sh -c "airflow connections --add --conn_id local_webapi_docker --conn_type http --conn_host host.docker.internal --conn_port 80"


```

NOTE: CONSIDER ADDING CONNECTIONS PROGRAMMATICALLY IF USED PERMANENTLY! (See `airflowapp/create_connections.py`)


#### Changing AWS Credentials

...


## Author

OlafMarangone
Contact [olaf.marangone@theprosperity.company](mailto:olaf.marangone@theprosperity.company)  
Initial work [Gitlab Link](https://gitlab.com/prosperitycompany/airflow).


## FAQ's

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

  * The LocalExecutor can parallelize task instances locally, but only works in a simple single-container-like environment (even though there is an option of connecting custom data bases, i.e. replacing sqlite with postgreSQL.

- How to set up Postgres usage instead of local sqlite?

  * To configure Airflow to use Postgres rather than the default Sqlite3, go to airflow.cfg and update this configuration to `LocalExecutor`

Airflow.cfg

```
# The executor class that airflow should use. Choices include
# SequentialExecutor, LocalExecutor, CeleryExecutor
executor = LocalExecutor


```


- How can a S3 Bucket be mounted to a local docker?

  * Use Docker Plugin RexRay: [https://rexray.readthedocs.io/en/stable/user-guide/storage-providers/aws/#aws-s3fs](https://rexray.readthedocs.io/en/stable/user-guide/storage-providers/aws/#aws-s3fs)

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





