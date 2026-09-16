import uuid


def set_job_context(spark, description):
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