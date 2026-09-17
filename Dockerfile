# Base image already contains:
# - Java / JVM
# - Spark 4.2.0
# - Python 3
# - PySpark under /opt/spark/python
FROM spark:4.2.0-python3

# Root is required to install Python packages and modify the spark user.
USER root

# Install additional Python libraries.
# delta-spark provides the Python-side Delta API.
COPY requirements.txt /tmp/requirements.txt

RUN python3 -m pip install \
    --no-cache-dir \
    -r /tmp/requirements.txt

# Allow commands such as:
# spark-submit
# spark-class
# spark-shell
ENV PATH="/opt/spark/bin:${PATH}"

# Allow normal Python/Jupyter processes to import the PySpark
# and Py4J bundled with the Spark image.
ENV PYTHONPATH="/workspace/jobs:/opt/spark/python:/opt/spark/python/lib/py4j-0.10.9.9-src.zip:${PYTHONPATH}"

# Spark's default user has /nonexistent as its home.
# Jupyter and Ivy need a writable home directory.
RUN mkdir -p /tmp/spark-home && \
    chown -R spark:spark /tmp/spark-home && \
    usermod -d /tmp/spark-home spark

ENV HOME="/tmp/spark-home"

# --------------------------------------------------
# Cache Delta JVM dependencies inside the image
# --------------------------------------------------
#
# This downloads Delta's JVM JARs once during docker build.
# They remain in /tmp/spark-home/.ivy2.5.2 inside the image.
#
# At runtime Spark can resolve them locally instead of
# downloading them again from Maven.
USER spark

RUN echo 'print("Delta dependencies cached")' > /tmp/delta_init.py && \
    /opt/spark/bin/spark-submit \
    --packages io.delta:delta-spark_4.2_2.13:4.4.0 \
    /tmp/delta_init.py && \
    rm /tmp/delta_init.py

# --------------------------------------------------
# Master startup script
# --------------------------------------------------
#
# Starts the Spark Master and JupyterLab.
USER root

COPY start-master.sh /opt/spark/start-master.sh

RUN chmod +x /opt/spark/start-master.sh && \
    chown spark:spark /opt/spark/start-master.sh


# Run Spark/Jupyter as the non-root spark user.
USER spark