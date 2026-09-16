from pyspark.sql import SparkSession

spark = (
    SparkSession.builder
    .appName("SparkLab-Test")
    .getOrCreate()
)

#Set log level
spark.sparkContext.setLogLevel("FATAL")

data = [
    (1, "Alice"),
    (2, "Bob"),
    (3, "Charlie"),
    (4, "David"),
]

df = spark.createDataFrame(data, ["id", "name"])

df.show()

spark.stop()