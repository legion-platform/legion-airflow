pipeline {
    agent { label 'ec2orchestrator'}

    environment {
        //Input parameters
        param_git_branch = "${params.GitBranch}"
        param_profile = "${params.Profile}"
        param_legion_airflow_version = "${params.LegionAirflowVersion}"
        param_legion_version = "${params.LegionVersion}"
        param_legion_branch = "${params.LegionBranch}"
        //Legion eclave name where to deploy Airflow
        param_enclave_name = "${params.Enclave}"
        param_deploy_airflow = "${params.DeployAirflow}"
        param_use_regression_tests = "${params.UseRegressionTests}"
        param_tests_tags = "${params.TestsTags}"
        param_legion_state_store = "${params.LegionStateStore}"
        param_legion_repo = "${params.LegionRepo}"
        param_docker_repo = "${params.DockerRepo}"
        param_helm_repo = "${params.HelmRepo}"
        param_debug_run = "${params.DebugRun}"
        //Job parameters
        sharedLibPath = "deploy/Pipeline.groovy"
        legionSharedLibPath = "legion/deploy/legionPipeline.groovy"
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
                    // Import legion-airflow components
                    legionAirflow = load "${env.sharedLibPath}"
                    
                    // import Legion components
                    dir("${WORKSPACE}/legion") {
                        
                        git branch: "${env.param_legion_branch}", poll: false, url: "${env.param_legion_repo}"
                    }
                    legion = load "${env.legionSharedLibPath}"
                    
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
                    git branch: "${env.param_legion_branch}", poll: false, url: "${env.param_legion_repo}"
                    sh "echo postdeploystep"
                }
                legion = load "${env.legionSharedLibPath}"
                legion.notifyBuild(currentBuild.currentResult)
            }
            deleteDir()
        }
    }
}