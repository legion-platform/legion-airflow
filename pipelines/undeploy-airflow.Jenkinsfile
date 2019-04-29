pipeline {
    agent { label 'ec2orchestrator'}

    environment {
        //Input parameters
        param_git_branch = "${params.GitBranch}"
        param_profile = "${params.Profile}"
        param_legion_airflow_version = "${params.LegionAirflowVersion}"
        //Legion Infra repo url (for pipeline methods import)
        param_legion_infra_repo = "${params.LegionInfraRepo}"
        //Legion repo version tag (tag or branch name)
        param_legion_infra_version = "${params.LegionInfraVersion}"
        //Legion eclave name where to deploy Airflow
        param_enclave_name = "${params.Enclave}"
        param_docker_repo = "${params.DockerRepo}"
        param_debug_run = "${params.DebugRun}"
        //Job parameters
        sharedLibPath = "pipelines/Pipeline.groovy"
        legionSharedLibPath = "pipelines/legionPipeline.groovy"
        cleanupContainerVersion = "latest"
        ansibleHome =  "/opt/legion/ansible"
        ansibleVerbose = '-v'
        helmLocalSrc = 'false'
        //Alternative profiles path with legion cluster parameters
        PROFILES_PATH = "${WORKSPACE}/legion/profiles"
    }

    stages {
        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm
                script {
                    sh 'echo RunningOn: $(curl http://checkip.amazonaws.com/)'

                    param_env_name = env.param_profile.split("\\.")[0]

                    // Import legion-airflow components
                    legionAirflow = load "${env.sharedLibPath}"
                    
                    // import Legion components
                    dir("${WORKSPACE}/legion") {
                        checkout scm: [$class: 'GitSCM', userRemoteConfigs: [[url: "${env.param_legion_infra_repo}"]], branches: [[name: "refs/tags/${env.param_legion_infra_version}"]]], poll: false 
                        legion = load "${env.legionSharedLibPath}"
                    }
                    
                    //Generate build description
                    legion.buildDescription()
                }
            }
        }

        /// Whitelist Jenkins Agent IP on cluster
        stage('Authorize Jenkins Agent') {
            steps {
                script {
                    legion.authorizeJenkinsAgent()
                }
            }
        }

        stage('Uneploy Ariflow') {
            steps {
                script {
                    legion.ansibleDebugRunCheck(env.param_debug_run)
                    legionAirflow.undeployAirflow()
                }
            }
        }
    }

    post {
        always {
            script {
                dir("${WORKSPACE}/legion") {
                    // import Legion components
                    checkout scm: [$class: 'GitSCM', userRemoteConfigs: [[url: "${env.param_legion_infra_repo}"]], branches: [[name: "refs/tags/${env.param_legion_infra_version}"]]], poll: false
                    legion = load "${env.legionSharedLibPath}"
                    legion.notifyBuild(currentBuild.currentResult)
                }
            }
        }
        cleanup {
            script {
                dir("${WORKSPACE}/legion") {
                    // import Legion components
                    checkout scm: [$class: 'GitSCM', userRemoteConfigs: [[url: "${env.param_legion_infra_repo}"]], branches: [[name: "refs/tags/${env.param_legion_infra_version}"]]], poll: false
                    legion = load "${env.legionSharedLibPath}"
                    // reset ansible home to defaults
                    ansibleHome = env.ansibleHome
                    legion.cleanupClusterSg(env.param_legion_infra_version ?: cleanupContainerVersion)
                }
            }
            deleteDir()
        }
    }

}