*** Settings ***
Documentation       Check if airflow components are secured
Resource            ../resources/keywords.robot
Variables           ../load_variables_from_profiles.py    ${PATH_TO_PROFILES_DIR}
Library             Collections
Library             legion_airflow_test.robot.Utils
 
*** Test Cases ***
Check if Airflow enclave domain has been secured
    [Tags]  airflow
    [Template]    Check if component domain has been secured
    component=airflow    enclave=${MODEL_TEST_ENCLAVE}

Check if Flower enclave domain has been secured
    [Tags]  airflow
    [Template]    Check if component domain has been secured
    component=flower    enclave=${MODEL_TEST_ENCLAVE}

Check if Airflow enclave does not auth with invalid creds
    [Tags]  airflow
    [Template]  Secured component domain should not be accessible by invalid credentials
    component=airflow    enclave=${MODEL_TEST_ENCLAVE}
 
Check if Flower enclave domain does not auth with invalid creds
    [Tags]  airflow
    [Template]    Secured component domain should not be accessible by invalid credentials
    component=flower    enclave=${MODEL_TEST_ENCLAVE}

#Check if Airflow enclave domain can auth with valid creds
#    [Tags]  airflow
#    [Template]    Secured component domain should be accessible by valid credentials
#    component=airflow    enclave=${MODEL_TEST_ENCLAVE}

Check if Flower enclave domain can auth with valid creds
    [Tags]  airflow
    [Template]    Secured component domain should be accessible by valid credentials
    component=flower    enclave=${MODEL_TEST_ENCLAVE}

Check test dags should not fail
    [Tags]  airflow
    [Template]   Invoke and check test dags for valid status code
    enclave=${MODEL_TEST_ENCLAVE}
