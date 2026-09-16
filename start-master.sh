#!/bin/bash
set -e

# History Server reads Spark event logs from this shared folder.
export SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=file:/workspace/spark-events"

# Start Spark Master in background.
/opt/spark/bin/spark-class \
  org.apache.spark.deploy.master.Master &

# Start Spark History Server in background.
/opt/spark/sbin/start-history-server.sh

# Start Jupyter in foreground so the container stays alive.
exec jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --IdentityProvider.token=spark-lab \
  --ServerApp.root_dir=/workspace