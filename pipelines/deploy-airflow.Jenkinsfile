pipeline {
    agent { label 'ec2orchestrator'}

    environment {
        //Input parameters
        param_git_branch = "${params.GitBranch}"
        param_profile = "${params.Profile}"
        param_legion_airflow_version = "${params.LegionAirflowVersion}"
        param_legion_version = "${params.LegionVersion}"
        //Legion release tag to be used for common pipeline tasks and orchestration container
        param_legion_release = "${params.LegionRelease}"
        //Legion eclave name where to deploy Airflow
        param_enclave_name = "${params.Enclave}"
        param_deploy_airflow = "${params.DeployAirflow}"
        param_use_regression_tests = "${params.UseRegressionTests}"
        param_legion_repo = "${params.LegionRepo}"
        param_docker_repo = "${params.DockerRepo}"
        param_helm_repo = "${params.HelmRepo}"
        param_debug_run = "${params.DebugRun}"
        //Job parameters

        sharedLibPath = "deploy/Pipeline.groovy"
        legionSharedLibPath = "deploy/legionPipeline.groovy"
        cleanupContainerVersion = "latest"
        ansibleHome =  "/opt/legion/deploy/ansible"
        ansibleVerbose = '-v'
        helmLocalSrc = 'false'
        //Alternative profiles path with legion cluster parameters
        PROFILES_PATH = "${WORKSPACE}/legion/deploy/profiles"
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
                        checkout scm: [$class: 'GitSCM', userRemoteConfigs: [[url: "${env.param_legion_repo}"]], branches: [[name: "refs/tags/${env.param_legion_version}"]]], poll: false 
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

        stage('Deploy Ariflow') {
            when {
                expression {return param_deploy_airflow == "true" }
            }
            steps {
                script {
                    legion.ansibleDebugRunCheck(env.param_debug_run)
                    legionAirflow.deployAirflow()
                }
            }
        }

        /// Run Robot tests
        stage('Run regression tests'){
            when {
                expression { return param_use_regression_tests == "true" }
            }
            steps {
                script {
                    legion.ansibleDebugRunCheck(env.param_debug_run)
                    legionAirflow.runRobotTests()
                }
            }
        }
    }

    post {
        always {
            script {
                dir("${WORKSPACE}/legion") {
                    // import Legion components
                    checkout scm: [$class: 'GitSCM', userRemoteConfigs: [[url: "${env.param_legion_repo}"]], branches: [[name: "refs/tags/${env.param_legion_version}"]]], poll: false
                    legion = load "${env.legionSharedLibPath}"
                    legion.notifyBuild(currentBuild.currentResult)
                }
            }
        }
        cleanup {
            script {
                 dir("${WORKSPACE}/legion") {
                    // import Legion components
                    checkout scm: [$class: 'GitSCM', userRemoteConfigs: [[url: "${env.param_legion_repo}"]], branches: [[name: "refs/tags/${env.param_legion_version}"]]], poll: false
                    legion = load "${env.legionSharedLibPath}"
                    // reset ansible home to defaults
                    ansibleHome = env.ansibleHome
                    legion.cleanupClusterSg(param_legion_version ?: cleanupContainerVersion)
                }
            }
            deleteDir()
        }
    }
}