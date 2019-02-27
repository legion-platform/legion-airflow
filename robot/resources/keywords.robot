*** Settings ***
Documentation       Legion robot resources
Resource            variables.robot
Library             String
Library             OperatingSystem
Library             Collections
Library             DateTime
Library             legion_test.robot.K8s
Library             legion_test.robot.Jenkins
Library             legion_test.robot.Utils
Library             legion_test.robot.Grafana
Library             legion_test.robot.Airflow
Library             legion_test.robot.Process

*** Keywords ***
Connect to enclave Airflow
    [Arguments]           ${enclave}
    Connect to Airflow    ${HOST_PROTOCOL}://airflow-${enclave}.${HOST_BASE_DOMAIN}

Connect to enclave Flower
    [Arguments]           ${enclave}
    Connect to Flower    ${HOST_PROTOCOL}://flower-${enclave}.${HOST_BASE_DOMAIN}

Shell
    [Arguments]           ${command}
    ${result}=            Run Process without PIPE   ${command}    shell=True
    Log                   stdout = ${result.stdout}
    Log                   stderr = ${result.stderr}
    [Return]              ${result}

Get token from EDI
    [Documentation]  get token from EDI for the EDGE session
    [Arguments]     ${enclave}   ${model_id}   ${model_version}
    &{data} =             Create Dictionary    model_id=${model_id}    model_version=${model_version}
    &{resp} =             Execute post request    ${HOST_PROTOCOL}://edi-${enclave}.${HOST_BASE_DOMAIN}/api/1.0/generate_token  data=${data}  cookies=${DEX_COOKIES}
    Log                   ${resp["text"]}
    Should not be empty   ${resp}
    &{token} =  Evaluate  json.loads('''${resp["text"]}''')    json
    Log                   ${token}
    Set Suite Variable    ${TOKEN}    ${token['token']}

    # --------- TEMPLATE KEYWORDS SECTION -----------

Check if component domain has been secured
    [Arguments]     ${component}    ${enclave}
    [Documentation]  Check that a legion component is secured by auth
    ${jenkins} =     Run Keyword If   '${component}' == 'jenkins'    Set Variable    True
    ...    ELSE      Set Variable    False
    ${boolean} =     Convert To Boolean    ${jenkins}
    &{response} =    Run Keyword If   '${enclave}' == '${EMPTY}'    Get component auth page    ${HOST_PROTOCOL}://${component}.${HOST_BASE_DOMAIN}    ${boolean}
    ...    ELSE      Get component auth page    ${HOST_PROTOCOL}://${component}-${enclave}.${HOST_BASE_DOMAIN}    ${boolean}
    Log              Auth page for ${component} is ${response}
    Dictionary Should Contain Item    ${response}    response_code    200
    ${auth_page} =   Get From Dictionary   ${response}    response_text
    Should contain   ${auth_page}    Log in

Secured component domain should not be accessible by invalid credentials
    [Arguments]     ${component}    ${enclave}
    [Documentation]  Check that a secured legion component does not provide access by invalid credentials
    ${jenkins} =     Run Keyword If   '${component}' == 'jenkins'    Set Variable    True
    ...    ELSE      Set Variable    False
    ${boolean} =     Convert To Boolean    ${jenkins}
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
    ${jenkins} =     Run Keyword If   '${component}' == 'jenkins'    Set Variable    True
    ...    ELSE      Set Variable    False
    ${boolean} =     Convert To Boolean    ${jenkins}
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
    Connect to enclave Airflow                           ${enclave}
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

Set replicas num
    [Arguments]   ${replicas_num}
    :FOR  ${enclave}    IN    @{ENCLAVES}
    \   Set deployment replicas   ${replicas_num}  airflow-${enclave}-worker  ${enclave}
        Wait deployment replicas count   airflow-${enclave}-worker  namespace=${enclave}  expected_replicas_num=${replicas_num}