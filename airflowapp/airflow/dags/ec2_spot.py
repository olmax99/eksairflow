from datetime import datetime, timedelta

import airflow
from airflow.models import DAG

default_args = {
    'owner': 'TreesN\'Qs'
    'start_date': datetime.utcnow(),
    # 'retry_delay': timedelta(minutes=2)
}

# -------------------------- Spot Bidding---------------------------------
#
# Bid on Spot instances and provide them to an ECS cluster for scaling.
# Parameters:
#   - task_deadline         <-- workload execution datetime
#   - task_compute          <-- cluster resources to scale to
#   - task_duration         <-- time workload needs to finish

# -------------- GET PARAMS RECEIVED FROM EXTERNAL TRIGGER-----------------
#
# $ airflow trigger_dag 'example_dag_conf' -r 'run_id' --conf '{"message":"value"}'
#
# def run_this_func(ds, **kwargs):
#     print("Remotely received value of {} for key=message".
#           format(kwargs['dag_run'].conf['message']))
#
# run_this = PythonOperator(
#     task_id='run_this',
#     provide_context=True,
#     python_callable=run_this_func,
#     dag=dag,
# )
# # You can also access the DagRun object in templates
# bash_task = BashOperator(
#     task_id="bash_task",
#     bash_command='echo "Here is the message: '
#                  '{{ dag_run.conf["message"] if dag_run else "" }}" ',
#     dag=dag,
# )

# externally triggered DAG: compute for workload needed - DEMO: Manual
dag = DAG(
    dag_id='spot_bid',
    default_args=default_args,
    schedule_interval=None
)

# TODO: Customize schedule interval according to bidding timeseries algorithm
t1_calc_interval = CustomOperator1(
    task_id='calculate_bidding_interval',
    param1="my_param_1",
    param2="my_param_2",
    paramN="my_param_n",
    dag=dag
)

# iterator needs to be transformed into collections.counter(1:(t1,p1), 2:(t2,p2), ... , n: (tn,pn))
for time, price in "{{ ti.xcom_pull(task_ids='calculate_bidding_interval', key='return_value' }}":
    t2_bidder = CustomOperator2(
        task_id=f'bid_for_{str(price)}_at_{str(time)}',
        param1="my_param_1",
        param2="my_param_2",
        paramN="my_param_n",
        dag=dag
    )

# ---------- alternative task path for if bidding not successful----------

t3_no_bid_scale = CustomOperator3(
    task_id='scale_cluster_on_demand',
    param1="my_param_1",
    param2="my_param_2",
    paramN="my_param_n",
    dag=dag
)

t4_get_and_scale = CustomOperator4(
    task_id='scale_cluster_with_spot',
    param1="my_param_1",
    param2="my_param_2",
    paramN="my_param_n",
    dag=dag
)
