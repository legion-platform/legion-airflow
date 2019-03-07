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
                        state_store=${env.param_legion_state_store} \
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

return this
