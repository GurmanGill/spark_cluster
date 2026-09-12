# Tiny Spark Docker Cluster

A small Spark 4.2.0 standalone cluster for learning partitions, shuffles, joins, skew, memory pressure, and executor behavior without requiring large datasets.

## Architecture

```text
Mac
│
└── Docker network: spark-net
    │
    ├── spark-master
    │   ├── 2 CPUs
    │   └── 1 GB RAM
    │
    ├── spark-worker-1
    ├── spark-worker-2
    ├── spark-worker-3
    └── spark-worker-4
        ├── 0.5 CPU each
        ├── 1 GB Docker RAM limit
        ├── 1 Spark core
        └── 768 MB advertised Spark memory
```

A typical application uses:

```text
Executor cores:   1
Executor memory:  512 MB
```

This leaves additional container memory for the worker JVM, Python worker, JVM native memory, network buffers, and other overhead.

---

## How the Cluster Starts

The master container starts the Spark Standalone Master:

```bash
spark-class org.apache.spark.deploy.master.Master
```

Each worker starts:

```bash
spark-class \
  org.apache.spark.deploy.worker.Worker \
  spark://spark-master:7077
```

The flow is:

```text
Worker starts
    ↓
Docker DNS resolves spark-master
    ↓
Worker connects to spark-master:7077
    ↓
Worker registers its cores and memory
    ↓
Master can schedule executors on it
```

---

## Ports

The master exposes:

```yaml
ports:
  - "7077:7077"
  - "9000:8080"
```

### 7077 — Spark Master

Used by Spark applications to connect to the cluster:

```text
spark://localhost:7077
```

Inside Docker:

```text
spark://spark-master:7077
```

### 9000 — Spark Master UI

Spark listens on `8080` inside the container, but it is mapped to `9000` on the Mac:

```text
Mac :9000
   ↓
Container :8080
```

Open:

```text
http://localhost:9000
```

The UI shows workers, cores, advertised memory, running applications, and completed applications.

---

## Build and Start

If the Dockerfile or dependencies changed:

```bash
docker compose up -d --build
```

Otherwise:

```bash
docker compose up -d
```

Check containers:

```bash
docker compose ps
```

Expected:

```text
spark-master
spark-worker-1
spark-worker-2
spark-worker-3
spark-worker-4
```

Check resource usage:

```bash
docker stats
```

Stop everything:

```bash
docker compose down
```

---

## Running a Spark Job Inside Docker

Enter the master:

```bash
docker exec -it spark-master bash
```

The local `jobs/` folder is mounted at:

```text
/jobs
```

Submit:

```bash
spark-submit \
  --master spark://spark-master:7077 \
  --executor-memory 512m \
  --executor-cores 1 \
  /jobs/test.py
```

Example `test.py`:

```python
from pyspark.sql import SparkSession

spark = (
    SparkSession.builder
    .appName("SparkLab-Test")
    .getOrCreate()
)

data = [
    (1, "Alice"),
    (2, "Bob"),
    (3, "Charlie"),
    (4, "David"),
]

df = spark.createDataFrame(data, ["id", "name"])

df.show()

spark.stop()
```

Output:

```text
+---+-------+
| id|   name|
+---+-------+
|  1|  Alice|
|  2|    Bob|
|  3|Charlie|
|  4|  David|
+---+-------+
```

---

## Running From the Mac

Because port `7077` is published, Spark can also be submitted from the host:

```bash
spark-submit \
  --master spark://localhost:7077 \
  --conf spark.driver.host=host.docker.internal \
  --executor-memory 512m \
  --executor-cores 1 \
  jobs/test.py
```

In this case:

```text
Driver → Mac

Master → Docker

Executors → Docker workers
```

`host.docker.internal` gives the Docker executors an address they can use to communicate back to the driver running on the Mac.

---

## Spark 4.2 Memory Limits

Spark 4.2 rejected a `256 MB` executor with:

```text
Executor memory must be at least 450 MiB
```

Therefore this does not work:

```bash
--executor-memory 256m
```

The practical minimum for this lab is approximately:

```text
Spark minimum executor heap ≈ 450 MB
Our executor heap           = 512 MB
```

Also remember:

```text
Executor memory ≠ total container memory
```

A worker needs memory for more than the executor heap:

```text
1 GB worker container
│
├── 512 MB executor heap
├── Spark Worker JVM
├── JVM native overhead
├── Python worker
├── network/shuffle buffers
└── other process overhead
```

This is why the Docker worker limit is larger than `spark.executor.memory`.

---

## Worker Memory vs Docker Memory

Docker controls the real hard limit:

```yaml
mem_limit: 1g
```

Spark advertises a smaller amount to the master:

```yaml
environment:
  SPARK_WORKER_CORES: 1
  SPARK_WORKER_MEMORY: 768m
```

The Spark UI displays:

```text
768 MB
```

because it shows the resources the worker advertises to Spark.

`docker stats` displays the actual container usage and Docker limit.

---

## Custom Python Environment

The Docker image is based on:

```dockerfile
FROM spark:4.2.0-python3
```

Additional Python libraries are defined in `.env`:

```env
PYTHON_PACKAGES=pandas pyarrow requests
```

Docker Compose passes this into the Dockerfile:

```yaml
build:
  context: .
  args:
    PYTHON_PACKAGES: ${PYTHON_PACKAGES}
```

The Dockerfile installs them:

```dockerfile
ARG PYTHON_PACKAGES

RUN python3 -m pip install --no-cache-dir ${PYTHON_PACKAGES}
```

---

## Custom Logging

Spark normally prints a large amount of `INFO` logging.

For this learning environment we use a custom:

```text
log4j2.properties
```

and copy it into:

```text
/opt/spark/conf/log4j2.properties
```

from the Dockerfile.

The goal is to suppress normal Spark infrastructure logs so the terminal mainly shows:

```text
df.show()
print(...)
errors
```

instead of hundreds of lines about schedulers, block managers, RPC connections, and executors.

Some JVM-level startup messages such as:

```text
WARNING: Using incubator modules: jdk.incubator.vector
```

may still appear because they are emitted outside normal Spark Log4j logging.

---

## Useful Commands

```bash
# Start
docker compose up -d

# Rebuild after Dockerfile/dependency changes
docker compose up -d --build

# Check containers
docker compose ps

# Watch CPU/RAM
docker stats

# Enter master
docker exec -it spark-master bash

# Worker logs
docker logs spark-worker-1

# Spark Master UI
http://localhost:9000

# Stop/remove cluster
docker compose down
```

## Goal of This Lab

Keep the cluster deliberately small and change one Spark variable at a time:

```text
partition count
repartition / coalesce
shuffle partitions
groupBy
sort / distinct
joins
broadcast joins
data skew
salting
cache / persist
AQE
executor memory
executor cores
```

This makes the effects visible with relatively small datasets instead of requiring multi-GB production-scale data.
