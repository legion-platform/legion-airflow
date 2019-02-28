pipeline {
    agent { label 'ec2orchestrator'}

    environment {
        //Input parameters
        param_git_branch = "${params.GitBranch}"
        param_profile = "${params.Profile}"
        param_legion_airflow_version = "${params.LegionAirflowVersion}"
        param_legion_version_tag = "${params.LegionVersionTag}"
        param_legion_repo = "${params.LegionRepo}"
        param_deploy_airflow = "${params.DeployAirflow}"
        param_create_jenkins_tests = "${params.CreateJenkinsTests}"
        param_use_regression_tests = "${params.UseRegressionTests}"
        param_tests_tags = "${params.TestsTags}"
        param_pypi_repo = "${params.PypiRepo}"
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
                    dir ("${WORKSPACE}/legion") {
                        git branch: "${env.param_legion_version_tag}", poll: false, url: "${env.param_legion_repo}"
                        legion = load "${env.legionSharedLibPath}"\
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
                    legionAirflow.runRobotTests(env.param_tests_tags ?: "")
                }
            }
        }
    }

    post {
        always {
            script {
                dir ("${WORKSPACE}/legion") {
                        git branch: "${env.param_legion_version_tag}", poll: false, url: "${env.param_legion_repo}"
                        legion = load "${env.legionSharedLibPath}"\
                    }
                legion.notifyBuild(currentBuild.currentResult)
            }
            deleteDir()
        }
    }
}