# gorgias-challenge

A small, containerized Flask app to provide a To Do list, deployed on Goole Cloud Engine.

## Features

The app implements a simple To Do list:

* The default view lists all pre-existing list items
* New items can be added
* Each pre-existing list item can be marked `Completed` or `Not Complete` for status tracking
* Each pre-existing list item can be deleted from the list

The production version of the the app is available via [http://34.105.210.145/](http://34.105.210.145/).

## Repository layout

* `.github` contains the github action workflow to generate and push a new container
* `devlocal` contains files needed for a local development/testing version (more details below)
* `todo-flask` contains all code (including `Dockerfile`) for the todo web app itself
* `yaml` contains all manifests needed to create the GKE infrastructure (services, pods, etc)


## Google Cloud Infrastructure

All components are deployed inside a single cluster, and the default namespace.

The flask app is fronted by a load balancer (service) with an external static IP address (`34.105.210.145`). The app itself is in a deployment with 3 replicas of the `flask` pod.

The PostgreSQL database is deployed as a primary and replica, each as its own StatefulSet pod, fronted by its own ClusterIP service.

Overview of the components:

```
$ kubectl get pods,services -o wide
NAME                         READY   STATUS    RESTARTS      AGE   IP           NODE                                             NOMINATED NODE   READINESS GATES
pod/flask-6bf6df6d94-j4mhc   1/1     Running   0             16h   10.64.0.15   gke-sre-flask-pgsql-default-pool-4387c29e-p41h   <none>           <none>
pod/flask-6bf6df6d94-j8ggl   1/1     Running   0             16h   10.64.1.12   gke-sre-flask-pgsql-default-pool-4387c29e-grc3   <none>           <none>
pod/flask-6bf6df6d94-xm8tf   1/1     Running   0             16h   10.64.2.13   gke-sre-flask-pgsql-default-pool-4387c29e-m0qx   <none>           <none>
pod/postgres-postgresql-0    2/2     Running   0             39h   10.64.1.7    gke-sre-flask-pgsql-default-pool-4387c29e-grc3   <none>           <none>
pod/postgres-replica-0       2/2     Running   1 (39h ago)   39h   10.64.2.9    gke-sre-flask-pgsql-default-pool-4387c29e-m0qx   <none>           <none>

NAME                              TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)        AGE     SELECTOR
service/flask                     LoadBalancer   34.118.236.197   34.105.210.145   80:32252/TCP   39h     app=flask
service/kubernetes                ClusterIP      34.118.224.1     <none>           443/TCP        2d22h   <none>
service/postgres-postgresql-svc   ClusterIP      34.118.229.148   <none>           5432/TCP       2d21h   statefulset.kubernetes.io/pod-name=postgres-postgresql-0
service/postgres-replica-svc      ClusterIP      34.118.227.89    <none>           5432/TCP       2d17h   statefulset.kubernetes.io/pod-name=postgres-replica-0
```

## Database Details

The two database clusters are:

* `postgres-postgresql-0`: primary (read/write), available via the `postgres-postgresql-svc` service
* `postgres-replica-0`: replica (read only), available via the `postgres-replica-svc` service

### Authentication

* To get the the password for the `postgres` (administrative) user in the database, run:
  ```
  kubectl get secret postgres-secret -o jsonpath="{.data.password}" | base64 -d
  ```

* To get the password for the `todolist` (app) user in the database, run:
  ```
  kubectl get secret sql-db-creds -o jsonpath="{.data.dbpasswd}" | base64 -d
  ```

### Connecting to the primary

A `psql` connection to the primary server, can be established by running:

```
kubectl exec -it postgres-postgresql-0 -c postgresql-server -- psql -U postgres todo
```

Current status of the primary database cluster:

```
todo=# \dt
           List of relations
 Schema |   Name    | Type  |  Owner   
--------+-----------+-------+----------
 public | todo_list | table | todolist
(1 row)

todo=# \d todo_list
                                 Table "public.todo_list"
  Column   |          Type          | Collation | Nullable |           Default            
-----------+------------------------+-----------+----------+------------------------------
 id        | bigint                 |           | not null | generated always as identity
 name      | character varying(100) |           | not null | 
 completed | boolean                |           | not null | false
Indexes:
    "todo_list_pkey" PRIMARY KEY, btree (id)
    
todo=# select * from todo_list order by id ;
 id |          name           | completed 
----+-------------------------+-----------
  1 | test item 0             | f
  3 | test item 2             | f
  5 | test item 4             | f
  7 | dns testing 0           | t
  8 | adding more             | f
  9 | another manifest update | t
 11 | testing 10              | t
(7 rows)

todo=# select now() ; select * from pg_stat_replication;
-[ RECORD 1 ]----------------------
now | 2025-03-26 19:52:03.339994+00

-[ RECORD 1 ]----+------------------------------
pid              | 30
usesysid         | 16388
usename          | replication
application_name | walreceiver
client_addr      | 10.64.1.13
client_hostname  | 
client_port      | 59882
backend_start    | 2025-03-26 19:31:16.414402+00
backend_xmin     | 
state            | streaming
sent_lsn         | 0/B003DF8
write_lsn        | 0/B003DF8
flush_lsn        | 0/B003DF8
replay_lsn       | 0/B003DF8
write_lag        | 
flush_lag        | 
replay_lag       | 
sync_priority    | 0
sync_state       | async
reply_time       | 2025-03-26 19:52:00.342295+00
```

### Connecting to the replica:


```
kubectl exec -it postgres-replica-0 -c postgresql-server -- psql -U postgres todo
```

Current status of the replica database cluster:

```
todo=# select * from todo_list order by id ;
 id |          name           | completed 
----+-------------------------+-----------
  1 | test item 0             | f
  3 | test item 2             | f
  5 | test item 4             | f
  7 | dns testing 0           | t
  8 | adding more             | f
  9 | another manifest update | t
 11 | testing 10              | t
(7 rows)

todo=# select now() ; select * from pg_stat_wal_receiver ;
-[ RECORD 1 ]----------------------
now | 2025-03-26 19:56:09.539048+00

-[ RECORD 1 ]---------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
pid                   | 26
status                | streaming
receive_start_lsn     | 0/B000000
receive_start_tli     | 1
written_lsn           | 0/B003DF8
flushed_lsn           | 0/B003DF8
received_tli          | 1
last_msg_send_time    | 2025-03-26 19:55:50.932593+00
last_msg_receipt_time | 2025-03-26 19:55:50.932658+00
latest_end_lsn        | 0/B003DF8
latest_end_time       | 2025-03-26 19:43:49.080067+00
slot_name             | slot2
sender_host           | 10.64.1.14
sender_port           | 5432
conninfo              | user=replication password=******** channel_binding=prefer dbname=replication host=10.64.1.14 port=5432 fallback_application_name=walreceiver sslmode=prefer sslcompression=0 sslcertmode=allow sslsni=1 ssl_min_protocol_version=TLSv1.2 gssencmode=prefer krbsrvname=postgres gssdelegation=0 target_session_attrs=any load_balance_hosts=disable
```

## Local development / usage

The web app can be deployed locally on any system that has basic Docker support available.
To do so, run the `devlocal/run_locally.sh` script.  This script will:

* pull a Postgres container, and import the expected database schema
* pull the todo app docker container
* run both containers, with the Todo app configured to connect to the Postgres instance
* output instructions on how to connect to the web UI


## Future improvements

* Per user lists support, so that each user isn't forced to share one list across all users
* Setup metrics/reporting (export) for usage trends and alerting purposes (Prometheus -> Grafana)
* More mature IaC tooling (using Terraform/Helm/Kustomize, etc) to support a larger, more complex deployment


Thanks for reading!
