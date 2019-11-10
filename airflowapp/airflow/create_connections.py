import json
import logging
import os
import sys

from airflow import settings
from airflow.models import Connection
from sqlalchemy.orm import exc

log = logging.Logger(__name__)


class InitializeConnections(object):

    def __init__(self):
        self.session = settings.Session()

    def has_connection(self, conn_id):
        try:
            (
                self.session.query(Connection)
                .filter(Connection.conn_id == conn_id)
                .one()
            )
        except exc.NoResultFound:
            return False
        return True

    def delete_all_connections(self):
        self.session.query(Connection.conn_id).delete()
        self.session.commit()

    def add_connection(self, **args):
        """
        conn_id, conn_type, extra, host, login,
        password, port, schema, uri
        """
        self.session.add(Connection(**args))
        self.session.commit()


if __name__ == "__main__":
    
    ic = InitializeConnections()

    # delete all the default connections
    log.info("Removing example connections")
    ic.delete_all_connections()

    # add default Google Platform connection
    # def create_gcp_conn(new_conn_id):
    #
    #     # skip initialization if connection exists
    #     if ic.has_connection(new_conn_id):
    #         log.info(f"Connection '{new_conn_id}' exists already.")
    #         sys.exit(0)
    #
    #     log.info(f"Adding default GCP connection: {new_conn_id}")
    #     scopes = ['https://www.googleapis.com/auth/cloud-platform']
    #
    #     with open('/usr/local/airflow/secrets/gcp_key.json', 'r') as fi:
    #         project_id = json.load(fi)['project_id']
    #     conn_extra = {
    #         "extra__google_cloud_platform__scope": ",".join(scopes),
    #         "extra__google_cloud_platform__project": project_id,
    #         "extra__google_cloud_platform__key_path": "/usr/local/airflow/secrets/gcp_key.json"
    #     }
    #     conn_extra_json = json.dumps(conn_extra)
    #     ic.add_connection(conn_id=new_conn_id,
    #                       conn_type="google_cloud_platform",
    #                       extra=conn_extra_json)
        
    # def create_example_conn(new_conn_id):
    #     user_login = os.environ['EXAMPLE_LOGIN']
    #     user_password = os.environ['EXAMPLE_PASSWORD']
    #
    #     # skip initialization if connection exists
    #     if ic.has_connection(new_conn_id):
    #         log.info(f"Connection '{new_conn_id}' exists already.")
    #         sys.exit(0)
    #
    #     log.info(f"Adding default EXAMPLE connection: {new_conn_id}")
    #     ic.add_connection(conn_id=new_conn_id,
    #                       conn_type="http",
    #                       host='my_endpoint',
    #                       login=user_login,
    #                       password=user_password,
    #                       port=443)

    # create_gcp_conn('google_cloud_default')
    # create_example_conn('my_endpoint')



