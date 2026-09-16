# Tiny Spark Docker Cluster

A lightweight local **Apache Spark 4.2.0** standalone cluster built with Docker for hands-on learning and experimentation.

The goal of this project is to make Spark internals easy to observe on a small machine without requiring large production-scale datasets.

## Capabilities

The cluster includes:

- **1 Spark Master**
- **4 Spark Workers**
- **JupyterLab** for interactive PySpark development
- **Delta Lake** support
- **Adaptive Query Execution (AQE)** experiments
- **Live Spark UI** for jobs, stages, tasks, executors, and SQL plans
- **Spark History Server** with persisted event logs
- Local `jobs/` and `data/` folders mounted directly into the cluster

It is designed to help you understand how Spark actually executes workloads:

```text
DataFrame operations
        ↓
Spark Jobs
        ↓
Stages
        ↓
Tasks
        ↓
Executors
        ↓
Worker CPU / Memory
```

## Ideal for experimenting:

- Partitions
- Repartition / Coalesce
- Shuffles
- Joins
- Broadcast Joins
- Sort-Merge Joins
- Aggregations
- Data Skew
- Salting
- AQE
- Caching
- Executor Memory
- Executor Cores
- Delta Tables
- Delta Transaction Logs
- Spark Job Groups
- Spark History

## What You Need

Install:

- Docker Desktop
- Git

Clone the repo:

```bash
git clone git@github.com:GurmanGill/spark_cluster.git
cd spark_cluster
```

Build and start everything:

```bash
docker compose up -d --build
```

Check the containers:

```bash
docker compose ps
```

Expected containers:

```text
spark-master
spark-worker-1
spark-worker-2
spark-worker-3
spark-worker-4
```

Stop the cluster:

```bash
docker compose down
```

## Open the UIs

| UI                   | URL                    | Purpose                                           |
| -------------------- | ---------------------- | ------------------------------------------------- |
| JupyterLab           | http://localhost:8888  | Run the notebooks                                 |
| Spark Master UI      | http://localhost:9000  | Workers, cores, memory, applications              |
| Spark Driver UI      | http://localhost:4040  | Live jobs, stages, tasks, executors and SQL plans |
| Spark History Server | http://localhost:18080 | View persisted Spark application history          |

Port `4040` becomes available after the notebook creates a `SparkSession`.

## Repo Layout

```text
spark_cluster/
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── start-master.sh
├── jobs/
│   ├── test.ipynb
│   └── spark_utils.py
├── data/
└── spark-events/
```

The local folders are mounted directly into the containers:

```text
Local repo                 Docker

./jobs         <------->   /workspace/jobs
./data         <------->   /workspace/data
./spark-events <------->   /workspace/spark-events
```

This means notebook, Python, data, Delta-table, and Spark event-log changes are immediately visible on your local machine and survive container recreation.

## Sample Notebook

Open:

```text
http://localhost:8888
```

Then open:

```text
jobs/test.ipynb
```

The notebook creates a Spark Driver and connects it to the standalone master:

```python
from delta import configure_spark_with_delta_pip
from pyspark.sql import SparkSession

builder = (
    SparkSession.builder
    .appName("DeltaLab")
    .master("spark://spark-master:7077")
    .config("spark.executor.memory", "1g")
    .config("spark.executor.cores", "1")
    .config("spark.eventLog.enabled", "true")
    .config("spark.eventLog.dir", "file:/workspace/spark-events")
    .config(
        "spark.sql.extensions",
        "io.delta.sql.DeltaSparkSessionExtension"
    )
    .config(
        "spark.sql.catalog.spark_catalog",
        "org.apache.spark.sql.delta.catalog.DeltaCatalog"
    )
)

spark = configure_spark_with_delta_pip(builder).getOrCreate()
```

The execution flow is:

```text
Jupyter notebook
      ↓
Python kernel
      ↓
Spark Driver JVM
      ↓
Spark Master
      ↓
Workers
      ↓
Executor JVMs
      ↓
Stages → Tasks → Partitions
```

When finished with the notebook Spark application:

```python
spark.stop()
```

The master and workers continue running; only the current Spark application stops.

## AQE

Adaptive Query Execution can be enabled from the notebook:

```python
spark.conf.set("spark.sql.adaptive.enabled", "true")
```

Use `localhost:4040` to compare stages, shuffle behavior, and physical plans with AQE enabled or disabled.

## Delta Lake

Python dependencies are defined in `requirements.txt`:

```text
jupyterlab==4.6.3
ipykernel
pandas
pyarrow
requests
delta-spark==4.4.0
```

The Docker image also downloads and caches the matching Delta JVM dependencies during image build, so the notebook does not need to download the Delta JARs every time a SparkSession starts.

Write a Delta table:

```python
result.write \
    .format("delta") \
    .mode("overwrite") \
    .save("/workspace/data/delta/category_summary")
```

A Delta table contains Parquet files plus its transaction log:

```text
data/delta/category_summary/
├── _delta_log/
└── part-....parquet
```

## Job Tracking

`jobs/spark_utils.py` provides a small helper that assigns a short UUID-based job group and readable description:

```python
from spark_utils import set_job_context

job_id = set_job_context(
    spark,
    "Read Delta table"
)
```

The Spark UI then groups the internal Spark jobs under IDs such as:

```text
JOB-6f44d309 - Read Delta table
```

One notebook action can create multiple Spark jobs. Each Spark job can contain multiple stages, and each stage contains tasks.

```text
Notebook action
      ↓
Job Group
      ↓
Spark Job(s)
      ↓
Stage(s)
      ↓
Task(s)
```

## Architecture

```text
Host / Mac
│
├── :8888   JupyterLab
├── :9000   Spark Master UI
├── :4040   Live Spark Driver UI
├── :18080  Spark History Server
│
└── Docker network: spark-net
    │
    ├── spark-master
    │   ├── 4 CPU limit
    │   ├── 1 GB RAM limit
    │   ├── Spark Master JVM
    │   ├── Spark History Server
    │   ├── JupyterLab
    │   └── Spark Driver JVM when a notebook starts Spark
    │
    ├── spark-worker-1
    ├── spark-worker-2
    ├── spark-worker-3
    └── spark-worker-4
        ├── 1 CPU each
        ├── 1 GB RAM each
        ├── 1 Spark core each
        └── Executor JVMs run application tasks
```

## How Startup Works

`docker-compose.yml` creates the `spark-net` Docker network and starts all five containers from the same image:

```text
spark_lab:4.2.0-python3
```

The master runs:

```text
/opt/spark/start-master.sh
```

That script starts three services inside the master container:

```text
Spark Master
Spark History Server
JupyterLab
```

Workers start with:

```bash
spark-class \
  org.apache.spark.deploy.worker.Worker \
  spark://spark-master:7077
```

Docker DNS resolves `spark-master`, allowing every worker to register with the master.

The worker configuration is:

```yaml
SPARK_WORKER_CORES: 1
SPARK_WORKER_MEMORY: 1g
```

## Spark History

The notebook writes Spark event logs to:

```text
/workspace/spark-events
```

which is mapped to:

```text
./spark-events
```

The History Server reads the same directory. Because the directory lives on the host, application history remains available after:

```bash
docker compose down
docker compose up -d
```

Open persisted history at:

```text
http://localhost:18080
```
