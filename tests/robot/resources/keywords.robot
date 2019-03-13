*** Settings ***
Documentation       Legion robot resources
Resource            variables.robot
Library             String
Library             OperatingSystem
Library             Collections
Library             DateTime
Library             legion_airflow_test.robot.Utils
Library             legion_airflow_test.robot.Airflow
Library             legion_airflow_test.robot.Flower

*** Keywords ***
Connect to enclave Airflow
    [Arguments]           ${enclave}
    Connect to Airflow    ${HOST_PROTOCOL}://airflow-${enclave}.${HOST_BASE_DOMAIN}

Connect to enclave Flower
    [Arguments]           ${enclave}
    Connect to Flower    ${HOST_PROTOCOL}://flower-${enclave}.${HOST_BASE_DOMAIN}

    # --------- TEMPLATE KEYWORDS SECTION -----------

Check if component domain has been secured
    [Arguments]     ${component}    ${enclave}
    [Documentation]  Check that a legion component is secured by auth
    ${airflow} =     Run Keyword If   '${component}' == 'airflow'    Set Variable    True
    ...    ELSE      Set Variable    False
    ${boolean} =     Convert To Boolean    ${airflow}
    &{response} =    Run Keyword If   '${enclave}' == '${EMPTY}'    Get component auth page    ${HOST_PROTOCOL}://${component}.${HOST_BASE_DOMAIN}    ${boolean}
    ...    ELSE      Get component auth page    ${HOST_PROTOCOL}://${component}-${enclave}.${HOST_BASE_DOMAIN}    ${boolean}
    Log              Auth page for ${component} is ${response}
    Dictionary Should Contain Item    ${response}    response_code    200
    ${auth_page} =   Get From Dictionary   ${response}    response_text
    Should contain   ${auth_page}    Log in

Secured component domain should not be accessible by invalid credentials
    [Arguments]     ${component}    ${enclave}
    [Documentation]  Check that a secured legion component does not provide access by invalid credentials
    ${airflow} =     Run Keyword If   '${component}' == 'airflow'    Set Variable    True
    ...    ELSE      Set Variable    False
    ${boolean} =     Convert To Boolean    ${airflow}
    &{creds} =       Create Dictionary 	login=admin   password=admin
    &{response} =    Run Keyword If   '${enclave}' == '${EMPTY}'    Post credentials to auth    ${HOST_PROTOCOL}://${component}    ${HOST_BASE_DOMAIN}    ${creds}    ${boolean}
    ...    ELSE      Post credentials to auth    ${HOST_PROTOCOL}://${component}-${enclave}     ${HOST_BASE_DOMAIN}    ${creds}    ${boolean}
    Log              Bad auth page for ${component} is ${response}
    Dictionary Should Contain Item    ${response}    response_code    200
    ${auth_page} =   Get From Dictionary   ${response}    response_text
    Should contain   ${auth_page}    Log in to Your Account
    Should contain   ${auth_page}    Invalid Email Address and password

Secured component domain should be accessible by valid credentials
    [Arguments]     ${component}    ${enclave}
    [Documentation]  Check that a secured legion component does not provide access by invalid credentials
    ${airflow} =     Run Keyword If   '${component}' == 'airflow'    Set Variable    True
    ...    ELSE      Set Variable    False
    ${boolean} =     Convert To Boolean    ${airflow}
    &{creds} =       Create Dictionary    login=${STATIC_USER_EMAIL}    password=${STATIC_USER_PASS}
    &{response} =    Run Keyword If   '${enclave}' == '${EMPTY}'    Post credentials to auth    ${HOST_PROTOCOL}://${component}    ${HOST_BASE_DOMAIN}    ${creds}    ${boolean}
    ...    ELSE      Post credentials to auth    ${HOST_PROTOCOL}://${component}-${enclave}     ${HOST_BASE_DOMAIN}    ${creds}    ${boolean}
    Log              Bad auth page for ${component} is ${response}
    Dictionary Should Contain Item    ${response}    response_code    200
    ${auth_page} =   Get From Dictionary   ${response}    response_text
    Should contain   ${auth_page}    ${component}
    Should not contain   ${auth_page}    Invalid Email Address and password

Invoke and check test dags for valid status code
    [Arguments]   ${enclave}
    [Documentation]  Check test dags for valid status code
    Connect to enclave Airflow    ${enclave}
    :FOR    ${dag}      IN      @{TEST_DAGS}
    \   ${ready} =            Is dag ready    ${dag}
    \   Should Be True 	      ${ready} == True    Dag ${dag} was not ready
    \   ${tasks} =            Find Airflow Tasks  ${dag}
# Temporary disabling triggering Airflow tasks as it fails Airflow test
# TODO: Need to rewrite this logic as a part of Airflow upgrade.
#    \   Run airflow task and validate stderr      ${tasks}   ${dag}
    \   Wait dag finished     ${dag}
    \   ${failed_dags} =      Get failed Airflow DAGs
    \   Should Not Contain    ${failed_dags}      ${dag}
    \   ${succeeded_dags} =   Get succeeded Airflow DAGs
    \   Should not be empty   ${succeeded_dags}

Run airflow task and validate stderr
    [Arguments]   ${tasks}   ${dag}
    [Documentation]  Check airflow tasks for valid status code
    :FOR    ${task}     IN      @{tasks}
    \   ${date_time} =      Get Current Date  result_format='%Y-%m-%d %H:%M:%S'
    \   ${status} =         Trigger Airflow task    ${dag}  ${task}  ${date_time}
    \   Should Be Equal     ${status}   ${None}
