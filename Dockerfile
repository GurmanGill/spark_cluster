# Base image already contains:
# - Java / JVM
# - Spark 4.2.0
# - Python 3
# - PySpark code under /opt/spark/python
FROM spark:4.2.0-python3


# Switch to root because installing OS/Python packages and modifying
# the spark user's home directory require elevated permissions.
USER root


# Install Python venv support.
# The base Spark image has Python, but Debian's python3-venv package
# is not installed by default.
#
# apt-get update        -> refresh package metadata
# apt-get install       -> install venv support
# rm /var/lib/apt/lists -> remove apt cache to keep the image smaller
RUN apt-get update && \
    apt-get install -y python3-venv && \
    rm -rf /var/lib/apt/lists/*


# Python packages are supplied from docker-compose/.env at build time.
#
# Example:
# PYTHON_PACKAGES="jupyterlab ipykernel pandas pyarrow requests"
ARG PYTHON_PACKAGES


# Install our additional Python libraries globally in the container.
#
# --no-cache-dir prevents pip from keeping downloaded package caches
# inside the Docker image.
RUN python3 -m pip install --no-cache-dir ${PYTHON_PACKAGES}


# Add Spark command-line tools to the shell PATH.
#
# This lets us run:
#   spark-submit
#   spark-class
#   spark-shell
#
# instead of:
#   /opt/spark/bin/spark-submit
ENV PATH="/opt/spark/bin:${PATH}"


# Make Spark's Python libraries available to normal Python processes
# such as the Jupyter Python kernel.
#
# /opt/spark/python
#   -> contains the pyspark Python package
#
# /opt/spark/python/lib/py4j-*.zip
#   -> contains Py4J, which PySpark uses to communicate with the JVM
#
# We use Spark's bundled PySpark/Py4J so the Python side matches
# the Spark 4.2.0 runtime already installed in this image.
ENV PYTHONPATH="/opt/spark/python:/opt/spark/python/lib/py4j-0.10.9.9-src.zip:${PYTHONPATH}"


# The Spark image defines the spark user's home as /nonexistent.
# That is normally fine for Spark daemons, but Jupyter needs a writable
# home directory for runtime files, configuration, kernels, etc.
#
# 1. Create a writable home
# 2. Give ownership to the spark user
# 3. Change the spark user's configured Linux home directory
RUN mkdir -p /tmp/spark-home && \
    chown -R spark:spark /tmp/spark-home && \
    usermod -d /tmp/spark-home spark


# Set HOME for processes started inside the container.
# Jupyter will now use /tmp/spark-home instead of /nonexistent.
ENV HOME="/tmp/spark-home"

# Copy master script, start spark and jupyter 
COPY start-master.sh /opt/spark/start-master.sh
USER root
RUN chmod +x /opt/spark/start-master.sh

# Drop root privileges.
# Spark Master, Workers, Jupyter, and our applications will run
# as the normal non-root spark user.
USER spark