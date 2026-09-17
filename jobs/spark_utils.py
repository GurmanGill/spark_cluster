import uuid


def set_job_context(spark, description):
    """
    Set a unique Spark job group and readable call-site description.

    This makes Spark jobs triggered by subsequent actions easier to identify
    in the Spark UI. A short UUID is generated for each logical operation and
    added to both the job group and the visible job description.

    Parameters
    ----------
    spark : pyspark.sql.SparkSession
        Active SparkSession whose SparkContext will be updated.

    description : str
        Human-readable description of the logical Spark operation.

    Returns
    -------
    str
        Generated job ID, for example: ``JOB-a31f72c8``.
    """
    job_id = f"JOB-{uuid.uuid4().hex[:8]}"
    full_description = f"{job_id} - {description}"

    sc = spark.sparkContext

    sc.setJobGroup(
        job_id,
        full_description
    )

    sc.setLocalProperty(
        "callSite.short",
        full_description
    )

    return job_id