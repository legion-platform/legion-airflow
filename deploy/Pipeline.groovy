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
                        --extra-vars "profile=${env.param_profile} \
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
                        --extra-vars "profile=${env.param_profile} \
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
                docker.image("${env.param_docker_repo}/legion-docker-agent:${env.param_legion_version}").inside("-e HOME=/opt/legion/deploy -v ${WORKSPACE}/deploy/profiles:/opt/legion/deploy/profiles -u root") {
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
                            sh """
                            echo "Starting robot tests"
                            cd tests/robot
                            rm -f *.xml

                            PATH_TO_PROFILES_DIR=\"../../deploy/ansible/vars\"
                            PATH_TO_PROFILE_FILE=\"\$PATH_TO_PROFILES_DIR/common-vars.yaml\"
                            PATH_TO_COOKIES=\"\$PATH_TO_PROFILES_DIR/cookies.dat\"

                            export CLUSTER_NAME=\"\$(yq -r .cluster_name \$PATH_TO_PROFILE_FILE)\"
                            export CLUSTER_STATE_STORE=\"\$(yq -r .state_store \$PATH_TO_PROFILE_FILE)\"
                            echo \"Loading kubectl config from \$CLUSTER_STATE_STORE for cluster \$CLUSTER_NAME\"
                            export CREDENTIAL_SECRETS=airflow_secrets.yaml"

                            aws s3 cp \$CLUSTER_STATE_STORE/vault/${env.param_profile} airflow_secrets.yaml
                            ansible-vault decrypt --vault-password-file=${vault} --output \$CREDENTIAL_SECRETS airflow_secrets.yaml

                            kops export kubecfg --name \$CLUSTER_NAME --state \$CLUSTER_STATE_STORE
                            
                            # Start Xvfb server in background
                            Xvfb :99 -ac &

                            # Get Auth cookies
                            DISPLAY=:99 \
                            PROFILE=${env.param_profile} LEGION_VERSION=${env.param_legion_version} \
                            jenkins_dex_client --path-to-profiles \$PATH_TO_PROFILES_DIR > \$PATH_TO_COOKIES

                            # Run Robot tests
                            DISPLAY=:99 \
                            PROFILE=${env.param_profile} LEGION_VERSION=${env.param_legion_version} PATH_TO_COOKIES=\$PATH_TO_COOKIES \
                            pabot --verbose --processes 6 --variable PATH_TO_PROFILES_DIR:\$PATH_TO_PROFILES_DIR --listener legion_test.process_reporter ${env.robot_tags} --outputdir . tests/**/*.robot || true

                            """

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
