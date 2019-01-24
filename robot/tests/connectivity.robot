*** Settings ***
Documentation       Check if all core components are secured
Resource            ../../resources/browser.robot
Resource            ../../resources/keywords.robot
Variables           ../../load_variables_from_profiles.py    ${PATH_TO_PROFILES_DIR}
Library             Collections
Library             legion_test.robot.K8s
Library             legion_test.robot.Utils
Force Tags          core  security  auth
Test Setup          Choose cluster context            ${CLUSTER_NAME}

*** Test Cases ***
Check if Airflow enclave does not auth with invalid creds
    [Tags]  apps
    [Template]    Secured component domain should not be accessible by invalid credentials
    component=airflow    enclave=${MODEL_TEST_ENCLAVE}

Check if Flower enclave domain does not auth with invalid creds
    [Tags]  apps
    [Template]    Secured component domain should not be accessible by invalid credentials
    component=flower    enclave=${MODEL_TEST_ENCLAVE}

Check if Airflow enclave domain has been secured
    [Tags]  apps
    [Template]    Check if component domain has been secured
    component=airflow    enclave=${MODEL_TEST_ENCLAVE}

Check if Flower enclave domain has been secured
    [Tags]  apps
    [Template]    Check if component domain has been secured
    component=flower    enclave=${MODEL_TEST_ENCLAVE}

Check if Airflow enclave can auth with valid creds
    [Tags]  apps
    [Template]    Secured component domain should be accessible by valid credentials
    component=airflow    enclave=${MODEL_TEST_ENCLAVE}

Check if Flower enclave can auth with valid creds
    [Tags]  apps
    [Template]    Secured component domain should be accessible by valid credentials
    component=flower    enclave=${MODEL_TEST_ENCLAVE}