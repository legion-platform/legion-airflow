*** Variables ***
@{TEST_DAGS}                        example_python_work  s3_connection_test
${S3_PARTITIONING_PATTERN}          year=%Y/month=%m/day=%d/%Y%m%d%H
# TODO: Two next lines should be removed when closing LEGION #499, #313, #316
${SERVICE_ACCOUNT}                  admin
${SERVICE_PASSWORD}                 admin