# Tiny Spark Docker Cluster

## Setup

```text
Mac host
├── spark-submit / Driver runs here
│
└── Docker
    ├── spark-master  → 2 CPU, 1 GB RAM
    ├── worker-1      → 0.5 CPU, 512 MB RAM
    ├── worker-2      → 0.5 CPU, 512 MB RAM
    ├── worker-3      → 0.5 CPU, 512 MB RAM
    └── worker-4      → 0.5 CPU, 512 MB RAM
```

All Spark containers share the Docker network `spark-net`.

## How Spark starts

The master container runs:

```bash
/opt/spark/bin/spark-class org.apache.spark.deploy.master.Master
```

This starts the Spark Standalone Master.

Each worker runs:

```bash
/opt/spark/bin/spark-class   org.apache.spark.deploy.worker.Worker   spark://spark-master:7077
```

Each worker therefore:

```text
starts
  ↓
finds spark-master through Docker DNS
  ↓
connects to spark-master:7077
  ↓
registers its cores and memory with the master
```

## Ports

The master publishes:

```yaml
ports:
  - "7077:7077"
  - "8080:8080"
```

`7077` is the Spark Standalone master connection port.

Because it is published, Spark running on the Mac can submit to:

```text
spark://localhost:7077
```

`8080` is the Spark Master Web UI.

Open:

```text
http://localhost:8080
```

to see registered workers and applications.

## Start the cluster

From the directory containing `docker-compose.yml`:

```bash
docker compose up -d
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

Then verify all four workers in:

```text
http://localhost:8080
```

## Submit a job from the Mac

The Spark driver runs on the Mac when `spark-submit` is executed from the Mac.

Docker workers therefore need an address they can use to connect back to that driver. Docker Desktop provides:

```text
host.docker.internal
```

Example:

```bash
spark-submit   --master spark://localhost:7077   --conf spark.driver.host=host.docker.internal   jobs/test.py
```

Flow:

```text
Mac spark-submit
     │
     │ localhost:7077
     ▼
Spark Master
     │
     ├── worker-1
     ├── worker-2
     ├── worker-3
     └── worker-4
          │
          └──── connect back to Driver
                 at host.docker.internal
```

## Stop the cluster

```bash
docker compose down
```

> Note: 512 MB is intentionally very small for a Spark worker container. It is useful for this lab, but some Spark applications or executor-memory settings may need to be increased if the JVM cannot start reliably.
