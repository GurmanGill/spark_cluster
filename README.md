# Tiny Spark Docker Cluster

A small Spark 4.2.0 standalone cluster for learning Spark locally with Docker. It includes 1 Spark master, 4 workers, JupyterLab, Spark UI access, AQE experiments, and Delta Lake support.

## Quick Start

### 1. Install

You need:

- Docker Desktop
- Git

### 2. Clone the repo

```bash
git clone git@github.com:GurmanGill/spark_cluster.git
cd spark_cluster
```

### 3. Build and start the cluster

```bash
docker compose up -d --build
```

Check the containers:

```bash
docker compose ps
```

You should see:

```text
spark-master
spark-worker-1
spark-worker-2
spark-worker-3
spark-worker-4
```

Stop the cluster with:

```bash
docker compose down
```

---

## Open the Interfaces

### Spark Cluster UI

```text
http://localhost:9000
```

This is the Spark Standalone Master UI. Use it to see:

- registered workers
- available cores and memory
- running applications
- completed applications

### Spark Jobs / Stages / Tasks UI

```text
http://localhost:4040
```

This is the Spark Driver UI for the active notebook Spark application. Use it to inspect:

- Jobs
- Stages
- Tasks
- Executors
- SQL plans
- Shuffle read/write

Port `4040` is available after a notebook creates a `SparkSession`.

### JupyterLab

```text
http://localhost:8888
```

The repo starts JupyterLab automatically inside the `spark-master` container.

Open `test.ipynb` from the `jobs/` folder to run the sample Spark code.

---

## Local Files and Docker Volumes

Docker Compose maps these local folders directly into every Spark container:

```yaml
volumes:
  - ./jobs:/jobs
  - ./data:/data
```

That means:

```text
Local repo                 Docker containers

./jobs        <--------->  /jobs
./data        <--------->  /data
```

You can edit notebooks, Python jobs, or data directly from your local repo and the changes are immediately visible inside the containers.

For example:

```text
jobs/test.ipynb
```

is available inside Docker as:

```text
/jobs/test.ipynb
```

Delta files written to:

```text
/data/delta/category_summary
```

are stored locally under:

```text
data/delta/category_summary
```

---

## How the Spark Test Notebook Works

The notebook creates a Spark Driver and connects it to the standalone Spark Master:

```python
from delta import configure_spark_with_delta_pip
from pyspark.sql import SparkSession

builder = (
    SparkSession.builder
    .appName("DeltaLab")
    .master("spark://spark-master:7077")
    .config("spark.executor.memory", "512m")
    .config("spark.executor.cores", "1")
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

The flow is:

```text
Jupyter notebook
      ↓
Python kernel
      ↓
Spark Driver JVM
      ↓
Spark Master
      ↓
Spark Workers
      ↓
Executor JVMs
      ↓
Tasks process partitions
```

### Adaptive Query Execution

AQE can be enabled in the notebook with:

```python
spark.conf.set("spark.sql.adaptive.enabled", "true")
```

Use the Spark Driver UI on port `4040` to compare jobs, stages, and query plans with AQE enabled or disabled.

---

## Delta Lake Support

Delta Lake is installed through `.env`:

```env
PYTHON_PACKAGES=jupyterlab ipykernel pandas pyarrow requests delta-spark==4.4.0
```

The notebook configures the Delta Spark extensions and catalog, so DataFrames can be written using:

```python
result.write \
    .format("delta") \
    .mode("overwrite") \
    .save("/data/delta/category_summary")
```

A Delta table contains Parquet data files plus a transaction log:

```text
category_summary/
├── _delta_log/
├── part-....parquet
└── part-....parquet
```

---

## Architecture

```text
Mac / Host
│
├── localhost:8888  → JupyterLab
├── localhost:9000  → Spark Master UI
├── localhost:4040  → Spark Driver UI
│
└── Docker network: spark-net
    │
    ├── spark-master
    │   ├── 2 CPUs
    │   ├── 1 GB RAM
    │   ├── Spark Master JVM
    │   ├── JupyterLab
    │   └── Spark Driver JVM when a notebook creates SparkSession
    │
    ├── spark-worker-1
    ├── spark-worker-2
    ├── spark-worker-3
    └── spark-worker-4
        ├── 0.5 CPU each
        ├── 1 GB RAM each
        ├── 1 Spark core each
        └── Executor JVMs run application tasks
```

---

## How Docker Compose Starts Everything

`docker-compose.yml` creates the custom `spark-net` network and starts all five containers from the same image:

```text
spark_lab:4.2.0-python3
```

### Master

The master runs:

```text
/opt/spark/start-master.sh
```

`start-master.sh` starts the Spark Master in the background:

```bash
spark-class org.apache.spark.deploy.master.Master
```

and keeps JupyterLab running in the foreground:

```bash
jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --IdentityProvider.token= \
  --ServerApp.root_dir=/jobs
```

### Workers

Each worker starts with:

```bash
spark-class \
  org.apache.spark.deploy.worker.Worker \
  spark://spark-master:7077
```

Docker DNS resolves the hostname `spark-master`, allowing every worker to register with the master.

Each worker is configured with:

```yaml
SPARK_WORKER_CORES: 1
SPARK_WORKER_MEMORY: 1g
```

---

## Environment and Image Setup

`.env` defines the Python packages installed during the Docker image build:

```env
PYTHON_PACKAGES=jupyterlab ipykernel pandas pyarrow requests delta-spark==4.4.0
```

Docker Compose passes this value into the Dockerfile:

```yaml
build:
  context: .
  args:
    PYTHON_PACKAGES: ${PYTHON_PACKAGES}
```

The Dockerfile starts from:

```dockerfile
FROM spark:4.2.0-python3
```

so Java, Spark, Python, and PySpark already come from the same Spark 4.2.0 image. The Dockerfile then adds Jupyter and the additional Python libraries used by this lab.

---

## Useful Commands

```bash
# Build and start
docker compose up -d --build

# Start without rebuilding
docker compose up -d

# Check containers
docker compose ps

# Watch CPU and RAM
docker stats

# Enter the master container
docker exec -it spark-master bash

# View worker logs
docker logs spark-worker-1

# Stop the cluster
docker compose down
```
