def deployAirflow() {
    withCredentials([
    file(credentialsId: "vault-airflow", variable: 'vault')]) {
        withAWS(credentials: 'kops') {
            wrap([$class: 'AnsiColorBuildWrapper', colorMapName: "xterm"]) {
                docker.image("${env.param_docker_repo}/k8s-airflow-ansible:${env.param_legion_airflow_version}").inside("-e HOME=/opt/legion/deploy -u root") {
                    stage('Deploy Legion') {
                        sh """
                        cd ${ansibleHome} && \
                        ansible-playbook deploy.yml \
                        ${ansibleVerbose} \
                        --vault-password-file=${vault} \
                        --extra-vars "param_env_name=${param_env_name} \
                        legion_airflow_version=${env.param_legion_airflow_version} \
                        helm_repo=${env.param_helm_repo} \
                        docker_repo=${env.param_docker_repo} \
                        helm_local_src=${helmLocalSrc} \
                        enclave=${env.param_enclave_name}"
                        """
                    }
                }
            }
        }
    }
}

def undeployAirflow() {
    withCredentials([
    file(credentialsId: "vault-airflow", variable: 'vault')]) {
        withAWS(credentials: 'kops') {
            wrap([$class: 'AnsiColorBuildWrapper', colorMapName: "xterm"]) {
                docker.image("${env.param_docker_repo}/k8s-airflow-ansible:${env.param_legion_airflow_version}").inside("-e HOME=/opt/legion/deploy -u root") {
                    stage('Undeploy Legion') {
                        sh """
                        cd ${ansibleHome} && \
                        ansible-playbook undeploy.yml \
                        ${ansibleVerbose} \
                        --vault-password-file=${vault} \
                        --extra-vars "param_env_name=${param_env_name} \
                        legion_airflow_version=${env.param_legion_airflow_version}  \
                        helm_repo=${env.param_helm_repo} \
                        docker_repo=${env.param_docker_repo} \
                        helm_local_src=${helmLocalSrc}"
                        """
                    }
                }
            }
        }
    }
}


def runRobotTests(tags="") {
    withCredentials([
    file(credentialsId: "vault-${env.param_profile}", variable: 'vault')]) {
        withAWS(credentials: 'kops') {
            wrap([$class: 'AnsiColorBuildWrapper', colorMapName: "xterm"]) {
                docker.image("${env.param_docker_repo}/airflow-docker-agent:${env.param_legion_version}").inside("-e HOME=/opt/legion/deploy -v ${WORKSPACE}/legion/deploy/profiles:/opt/legion/deploy/profiles -u root") {
                    stage('Run Robot tests') {
                        dir("${WORKSPACE}"){
                            def nose_report = 0
                            def robot_report = 0
                            def tags_list = tags.toString().trim().split(',')
                            def robot_tags = []
                            def nose_tags = []
                            for (item in tags_list) {
                                if (item.startsWith('-')) {
                                    item = item.replace("-","")
                                    robot_tags.add(" -e ${item}")
                                    nose_tags.add(" -a !${item}")
                                    }
                                else if (item?.trim()) {
                                    robot_tags.add(" -i ${item}")
                                    nose_tags.add(" -a ${item}")
                                    }
                                }
                            env.robot_tags= robot_tags.join(" ")
                            env.nose_tags = nose_tags.join(" ")
                            sh "./tests/robot/run_robot_tests.sh ${env.param_profile} ${env.param_legion_version}"

                            robot_report = sh(script: 'find tests/robot/ -name "*.xml" | wc -l', returnStdout: true)

                            if (robot_report.toInteger() > 0) {
                                step([
                                    $class : 'RobotPublisher',
                                    outputPath : 'tests/robot/',
                                    outputFileName : "*.xml",
                                    disableArchiveOutput : false,
                                    passThreshold : 100,
                                    unstableThreshold: 95.0,
                                    onlyCritical : true,
                                    otherFiles : "*.png",
                                ])
                            }
                            else {
                                echo "No '*.xml' files for generating robot report"
                            }

                            if ((robot_report.toInteger() > 0) && !tags) {
                                echo "All tests were run but no reports found. Marking build as UNSTABLE"
                                currentBuild.result = 'UNSTABLE'
                            }
                            if ((robot_report.toInteger() > 0) && tags) {
                                echo "No tests were run during this build. Marking build as UNSTABLE"
                                currentBuild.result = 'UNSTABLE'
                            }     

                        }
                    }
                }
            }
        }
    }
}

return this
