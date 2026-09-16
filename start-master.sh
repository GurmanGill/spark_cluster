#!/bin/bash
set -e

# Start Spark Master in background
/opt/spark/bin/spark-class \
  org.apache.spark.deploy.master.Master &

# Start Jupyter in foreground
jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --IdentityProvider.token= \
  --ServerApp.root_dir=/workspace