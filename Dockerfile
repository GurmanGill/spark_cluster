FROM spark:4.2.0-python3

# Temporarily use root so packages can be installed
USER root

# Receives package list from Docker Compose / .env
ARG PYTHON_PACKAGES

# Install common Python libraries into the image
RUN python3 -m pip install --no-cache-dir ${PYTHON_PACKAGES}

# Allow Spark commands like spark-submit to be found directly
ENV PATH="/opt/spark/bin:${PATH}"

# Allow Python to find the PySpark package
ENV PYTHONPATH="/opt/spark/python:${PYTHONPATH}"

# Config spark logs
COPY log4j2.properties /opt/spark/conf/log4j2.properties

# Run Spark processes as the non-root spark user
USER spark