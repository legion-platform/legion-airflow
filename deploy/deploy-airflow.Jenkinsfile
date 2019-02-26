pipeline {
    agent { label 'ec2orchestrator'}

    environment {
        //Input parameters
        param_git_branch = "${params.GitBranch}"
        param_profile = "${params.Profile}"
        param_legion_version = "${params.LegionVersion}"
        param_legion_airflow_version = "${params.LegionAirflowVersion}"
        param_deploy_legion = "${params.DeployLegion}"
        param_create_jenkins_tests = "${params.CreateJenkinsTests}"
        param_use_regression_tests = "${params.UseRegressionTests}"
        param_tests_tags = "${params.TestsTags}"
        param_pypi_repo = "${params.PypiRepo}"
        param_docker_repo = "${params.DockerRepo}"
        param_helm_repo = "${params.HelmRepo}"
        param_debug_run = "${params.DebugRun}"
        //Job parameters
        sharedLibPath = "deploy/legionPipeline.groovy"
        commitID = null
        cleanupContainerVersion = "latest"
        ansibleHome =  "/opt/legion/deploy/ansible"
        ansibleVerbose = '-v'
        helmLocalSrc = 'false'
    }

    stages {
        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm
                script {
                    legion = load "${env.sharedLibPath}"
                    legion.buildDescription()
                    commitID = env.GIT_COMMIT
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


        /// Deploy Airflow component to Legion cluster
        stage('Deploy Ariflow') {
            when {
                expression {return param_deploy_legion == "true" }
            }
            steps {
                script {
                    legion.ansibleDebugRunCheck(env.param_debug_run)
                    legion.deployLegion()
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
                    legion.runRobotTests(env.param_tests_tags ?: "")
                }
            }
        }
    }

    post {
        always {
            script {
                legion = load "${sharedLibPath}"
                legion.cleanupClusterSg(param_legion_version ?: cleanupContainerVersion)
                legion.notifyBuild(currentBuild.currentResult)
            }
            deleteDir()
        }
    }
}